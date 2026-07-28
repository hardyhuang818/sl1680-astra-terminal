// astra_xiaozhi —— SL1680 的 xiaozhi 协议客户端（云端大脑模式）
//
// 链路: ALSA采集16k → Opus编码(60ms帧) → WebSocket → xiaozhi-server(PC)
//       ← Opus 24k ← TTS ← LLM(LM Studio 4090) ← SenseVoice ASR
//
// 设计要点:
//   - WebSocket 客户端手写(RFC6455, ~200行)，不依赖 libwebsockets 头文件
//   - VAD 在服务端(SileroVAD)，客户端只管持续推流 → 程序极简
//   - 服务端 python json.dumps 默认 ensure_ascii=True，中文以 \uXXXX 到达，
//     必须解码后再写状态文件，否则 dl_face 字幕全是转义串
//   - 播放期间丢弃采集帧(土办法防回声，与 astra_voice 同策略)
//   - 断线自动重连；服务端 120s 无语音会主动断开，属正常，重连即可
//
// 构建: 见 build-wsl.sh (Yocto cross gcc + gst-plugins-base recipe-sysroot)
// 用法: astra_xiaozhi --server ws://192.168.5.x:8000/xiaozhi/v1/ \
//                     [--dev-in plughw:CARD=C920] [--dev-out plughw:CARD=Edition]
//                     [--text "你好"] [--status /tmp/astra_status.txt] [-v]

#include <alsa/asoundlib.h>
#include <arpa/inet.h>
#include <errno.h>
#include <netdb.h>
#include <opus/opus.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>

#define UP_RATE     16000                 // 上行采样率(协议规定)
#define FRAME_MS    60
#define UP_SAMPLES  (UP_RATE * FRAME_MS / 1000)   // 960
#define MAX_PKT     4000
#define MAX_TXT     8192

static volatile int g_run = 1;
static void on_sigint(int s) { (void)s; g_run = 0; }

// 视觉唤醒：vision_wake 检测到有人走近 → SIGUSR1 → 让 LLM 主动打招呼。
// 注意必须用 sigaction 且不带 SA_RESTART——glibc 的 signal() 默认自动重启
// 系统调用，recv 永远不会被打断，信号就"看不见"了。
static volatile sig_atomic_t g_wake = 0;
static void on_sigusr1(int s) { (void)s; g_wake = 1; }

static int g_verbose = 0;
#define LOGV(...) do { if (g_verbose) fprintf(stderr, "[xz] " __VA_ARGS__); } while (0)
#define LOGI(...) fprintf(stderr, "[xz] " __VA_ARGS__)

// ---------------------------------------------------------------- 状态文件(dl_face 读)

static const char *g_status_path = NULL;
static char g_heard[MAX_TXT], g_reply[MAX_TXT];

static void write_status(const char *state) {
  if (!g_status_path) return;
  char tmp[600];
  snprintf(tmp, sizeof tmp, "%s.tmp", g_status_path);
  FILE *f = fopen(tmp, "w");
  if (!f) return;
  fprintf(f, "STATE=%s\nHEARD=%s\nREPLY=%s\n", state, g_heard, g_reply);
  fclose(f);
  rename(tmp, g_status_path);
}

// ---------------------------------------------------------------- 迷你 JSON 取值

// 从 json 中取 "key":"..." 字符串值，解码 \uXXXX(含代理对)/\n/\"等 → UTF-8。
// 找不到返回 0。只做提取不做完整解析——服务端消息扁平且字段固定，够用。
static int utf8_put(char *out, int pos, int cap, unsigned cp) {
  if (cp < 0x80) { if (pos + 1 >= cap) return pos; out[pos++] = cp; }
  else if (cp < 0x800) {
    if (pos + 2 >= cap) return pos;
    out[pos++] = 0xC0 | (cp >> 6); out[pos++] = 0x80 | (cp & 0x3F);
  } else if (cp < 0x10000) {
    if (pos + 3 >= cap) return pos;
    out[pos++] = 0xE0 | (cp >> 12); out[pos++] = 0x80 | ((cp >> 6) & 0x3F);
    out[pos++] = 0x80 | (cp & 0x3F);
  } else {
    if (pos + 4 >= cap) return pos;
    out[pos++] = 0xF0 | (cp >> 18); out[pos++] = 0x80 | ((cp >> 12) & 0x3F);
    out[pos++] = 0x80 | ((cp >> 6) & 0x3F); out[pos++] = 0x80 | (cp & 0x3F);
  }
  return pos;
}

static int json_str(const char *json, const char *key, char *out, int cap) {
  char pat[64];
  snprintf(pat, sizeof pat, "\"%s\"", key);
  const char *p = strstr(json, pat);
  if (!p) return 0;
  p += strlen(pat);
  while (*p == ' ' || *p == ':') p++;
  if (*p != '"') return 0;
  p++;
  int pos = 0;
  while (*p && *p != '"' && pos < cap - 4) {
    if (*p == '\\') {
      p++;
      if (*p == 'u') {
        unsigned cp = 0;
        if (sscanf(p + 1, "%4x", &cp) != 1) break;
        p += 5;
        if (cp >= 0xD800 && cp <= 0xDBFF && p[0] == '\\' && p[1] == 'u') {
          unsigned lo = 0;
          if (sscanf(p + 2, "%4x", &lo) == 1 && lo >= 0xDC00 && lo <= 0xDFFF) {
            cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00);
            p += 6;
          }
        }
        pos = utf8_put(out, pos, cap, cp);
      } else {
        char c = *p++;
        out[pos++] = (c == 'n') ? '\n' : (c == 't') ? '\t' : c;
      }
    } else {
      out[pos++] = *p++;
    }
  }
  out[pos] = 0;
  return 1;
}

static int json_int(const char *json, const char *key, int *out) {
  char pat[64];
  snprintf(pat, sizeof pat, "\"%s\"", key);
  const char *p = strstr(json, pat);
  if (!p) return 0;
  p += strlen(pat);
  while (*p == ' ' || *p == ':') p++;
  return sscanf(p, "%d", out) == 1;
}

// ---------------------------------------------------------------- WebSocket

typedef struct {
  int fd;
  pthread_mutex_t wlock;   // 采集线程和主线程都会写
} ws_t;

static void maybe_greet(void);   // 前置声明：EINTR 时检查视觉唤醒

static int read_n(int fd, uint8_t *buf, size_t n) {
  size_t got = 0;
  while (got < n) {
    ssize_t r = recv(fd, buf + got, n - got, 0);
    if (r < 0 && errno == EINTR) {
      if (!g_run) return -1;   // SIGTERM：立刻放弃连接，快速退出(别拖住麦克风)
      maybe_greet();
      continue;
    }
    if (r <= 0) return -1;
    got += r;
  }
  return 0;
}

// opcode: 0x1 text 0x2 binary 0x8 close 0x9 ping 0xA pong
static int ws_send(ws_t *ws, int opcode, const uint8_t *payload, size_t len) {
  uint8_t hdr[14];
  size_t h = 0;
  hdr[h++] = 0x80 | opcode;
  uint8_t mask[4] = { rand(), rand(), rand(), rand() };
  if (len < 126) hdr[h++] = 0x80 | len;
  else if (len < 65536) {
    hdr[h++] = 0x80 | 126;
    hdr[h++] = len >> 8; hdr[h++] = len & 0xFF;
  } else {
    hdr[h++] = 0x80 | 127;
    for (int i = 7; i >= 0; i--) hdr[h++] = (uint64_t)len >> (8 * i);
  }
  memcpy(hdr + h, mask, 4); h += 4;

  uint8_t *m = malloc(len ? len : 1);
  for (size_t i = 0; i < len; i++) m[i] = payload[i] ^ mask[i & 3];

  pthread_mutex_lock(&ws->wlock);
  int ok = (send(ws->fd, hdr, h, MSG_NOSIGNAL) == (ssize_t)h) &&
           (len == 0 || send(ws->fd, m, len, MSG_NOSIGNAL) == (ssize_t)len);
  pthread_mutex_unlock(&ws->wlock);
  free(m);
  return ok ? 0 : -1;
}

static int ws_send_text(ws_t *ws, const char *s) {
  LOGV("-> %s\n", s);
  return ws_send(ws, 0x1, (const uint8_t *)s, strlen(s));
}

// 收一帧。返回 opcode，-1=错误/断开。payload 写入 buf(容量 cap)，*plen 为长度。
// 自动回 pong；对分片帧按顺序拼接(罕见，服务端消息都很小)。
static int ws_recv(ws_t *ws, uint8_t *buf, size_t cap, size_t *plen) {
  size_t total = 0;
  int first_op = -1;
  for (;;) {
    uint8_t h2[2];
    if (read_n(ws->fd, h2, 2)) return -1;
    int fin = h2[0] & 0x80, op = h2[0] & 0x0F;
    uint64_t len = h2[1] & 0x7F;
    if (len == 126) {
      uint8_t e[2]; if (read_n(ws->fd, e, 2)) return -1;
      len = (e[0] << 8) | e[1];
    } else if (len == 127) {
      uint8_t e[8]; if (read_n(ws->fd, e, 8)) return -1;
      len = 0; for (int i = 0; i < 8; i++) len = (len << 8) | e[i];
    }
    if (h2[1] & 0x80) { uint8_t mk[4]; if (read_n(ws->fd, mk, 4)) return -1; } // 服务端帧不应带mask，防御性读掉
    if (total + len > cap) return -1;
    if (len && read_n(ws->fd, buf + total, len)) return -1;

    if (op == 0x9) { ws_send(ws, 0xA, buf + total, len); continue; }  // ping->pong
    if (op == 0xA) continue;                                           // pong 忽略
    if (op == 0x8) return 0x8;
    if (op != 0x0) first_op = op;
    total += len;
    if (fin) { *plen = total; return first_op; }
  }
}

// ws://host:port/path 握手
static int ws_connect(ws_t *ws, const char *url, const char *device_id) {
  char host[256], path[256];
  int port = 80;
  if (sscanf(url, "ws://%255[^:/]:%d%255s", host, &port, path) < 2) {
    if (sscanf(url, "ws://%255[^/]%255s", host, path) < 1) return -1;
  }
  if (!path[0]) strcpy(path, "/");

  struct addrinfo hints = { .ai_family = AF_INET, .ai_socktype = SOCK_STREAM }, *ai;
  char ports[16];
  snprintf(ports, sizeof ports, "%d", port);
  if (getaddrinfo(host, ports, &hints, &ai)) { LOGI("DNS 解析失败: %s\n", host); return -1; }
  ws->fd = socket(ai->ai_family, ai->ai_socktype, 0);
  struct timeval tv = { .tv_sec = 10 };
  setsockopt(ws->fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof tv);
  if (connect(ws->fd, ai->ai_addr, ai->ai_addrlen)) {
    LOGI("连不上 %s:%d: %s\n", host, port, strerror(errno));
    freeaddrinfo(ai); close(ws->fd); return -1;
  }
  freeaddrinfo(ai);

  char req[1024];
  snprintf(req, sizeof req,
           "GET %s HTTP/1.1\r\n"
           "Host: %s:%d\r\n"
           "Upgrade: websocket\r\n"
           "Connection: Upgrade\r\n"
           "Sec-WebSocket-Key: c2wxNjgwYXN0cmF4ekNsaQ==\r\n"   // 必须解码=16字节，服务端会校验
           "Sec-WebSocket-Version: 13\r\n"
           "device-id: %s\r\n"
           "client-id: sl1680-astra\r\n"
           "protocol-version: 1\r\n\r\n",
           path, host, port, device_id);
  if (send(ws->fd, req, strlen(req), MSG_NOSIGNAL) != (ssize_t)strlen(req)) { close(ws->fd); return -1; }

  // 读到 \r\n\r\n 为止
  char resp[2048];
  size_t got = 0;
  while (got < sizeof resp - 1) {
    ssize_t r = recv(ws->fd, resp + got, 1, 0);
    if (r <= 0) { close(ws->fd); return -1; }
    got += r;
    if (got >= 4 && !memcmp(resp + got - 4, "\r\n\r\n", 4)) break;
  }
  resp[got] = 0;
  if (!strstr(resp, " 101 ")) {
    LOGI("握手被拒: %.120s\n", resp);
    close(ws->fd); return -1;
  }
  // 握手完成后取消读超时(空闲时可能长时间无下行)
  struct timeval tv0 = { 0 };
  setsockopt(ws->fd, SOL_SOCKET, SO_RCVTIMEO, &tv0, sizeof tv0);
  pthread_mutex_init(&ws->wlock, NULL);
  return 0;
}

// ---------------------------------------------------------------- ALSA (沿用 astra_voice 的写法)

static snd_pcm_t *open_pcm(const char *dev, snd_pcm_stream_t dir, unsigned rate) {
  snd_pcm_t *h = NULL;
  if (snd_pcm_open(&h, dev, dir, 0) < 0) {
    LOGI("打不开 %s (%s)\n", dev, dir == SND_PCM_STREAM_CAPTURE ? "capture" : "playback");
    return NULL;
  }
  if (snd_pcm_set_params(h, SND_PCM_FORMAT_S16_LE, SND_PCM_ACCESS_RW_INTERLEAVED,
                         1, rate, 1, 500000) < 0) {
    snd_pcm_close(h);
    return NULL;
  }
  return h;
}

// ---------------------------------------------------------------- 全局运行态

static ws_t g_ws;
static volatile int g_connected = 0;
static volatile int g_speaking = 0;    // TTS 播放中 → 采集丢帧防回声

// 语音暂停("闭嘴"指令)：0=正常；-1=一直暂停直到视觉唤醒；>0=暂停到该时间戳(秒)
static volatile long g_pause_until = 0;
static int chat_paused(void) {
  long pu = g_pause_until;
  if (pu == 0) return 0;
  if (pu < 0) return 1;
  if (time(NULL) < pu) return 1;
  g_pause_until = 0;                    // 到点自动恢复
  LOGI("[暂停] 时间到，恢复聆听\n");
  return 0;
}
static char g_session[80] = "";
static int g_dl_rate = 24000;          // 下行采样率，以服务端 hello 为准
static snd_pcm_t *g_out = NULL;
static const char *g_dev_out = NULL;
static OpusDecoder *g_dec = NULL;

// ---------------------------------------------------------------- 采集线程

static void *capture_thread(void *arg) {
  const char *dev = arg;
  // 打不开不退出，重试到成功——设备可能被 astra-voice 暂占，或麦克风还没插
  snd_pcm_t *in = NULL;
  while (g_run && !(in = open_pcm(dev, SND_PCM_STREAM_CAPTURE, UP_RATE))) {
    LOGI("麦克风 %s 暂不可用，3 秒后重试\n", dev);
    for (int i = 0; i < 30 && g_run; i++) usleep(100 * 1000);
  }
  if (!in) return NULL;
  LOGI("麦克风 %s 已就绪，开始推流\n", dev);

  OpusEncoder *enc;
  int err;
  enc = opus_encoder_create(UP_RATE, 1, OPUS_APPLICATION_VOIP, &err);
  opus_encoder_ctl(enc, OPUS_SET_BITRATE(24000));
  opus_encoder_ctl(enc, OPUS_SET_COMPLEXITY(5));   // MCU 抄 0 是自我削弱，A73 用 5

  int16_t pcm[UP_SAMPLES];
  uint8_t pkt[MAX_PKT];
  while (g_run) {
    snd_pcm_sframes_t n = snd_pcm_readi(in, pcm, UP_SAMPLES);
    if (n < 0) { snd_pcm_recover(in, n, 1); continue; }
    if (n < UP_SAMPLES) continue;
    if (!g_connected || g_speaking || chat_paused()) continue;   // 未连接/播放中/已暂停都不推流
    int len = opus_encode(enc, pcm, UP_SAMPLES, pkt, sizeof pkt);
    if (len > 0 && ws_send(&g_ws, 0x2, pkt, len)) {
      LOGV("上行发送失败，等待重连\n");
    }
  }
  opus_encoder_destroy(enc);
  snd_pcm_close(in);
  return NULL;
}

// ---------------------------------------------------------------- 下行音频

static void play_opus(const uint8_t *pkt, size_t len) {
  static int16_t pcm[5760];
  if (!g_dec) return;
  int n = opus_decode(g_dec, pkt, len, pcm, 5760, 0);
  if (n <= 0) return;
  if (!g_out) {
    g_out = open_pcm(g_dev_out, SND_PCM_STREAM_PLAYBACK, g_dl_rate);
    if (!g_out) return;
  }
  snd_pcm_sframes_t w = snd_pcm_writei(g_out, pcm, n);
  if (w < 0) snd_pcm_recover(g_out, w, 1);
}

// ---------------------------------------------------------------- MCP 设备侧
//
// 服务端(MCP client) → 设备(MCP server)：
//   initialize(id=1) → 我方回 serverInfo → 1s 后 tools/list(id=2) → 我方回工具表
//   对话中 LLM 决定调用 → tools/call(id=N, params.name/arguments) → 我方执行并回
//   {"content":[{"type":"text","text":"..."}],"isError":false}
// 消息都包在 {"type":"mcp","payload":{...}} 里。
// 工具名只用 [a-zA-Z0-9_]（服务端会把其它字符替换成下划线，名字变了 LLM 会困惑）。

static int run_cmd(const char *cmd, char *out, int cap) {
  FILE *p = popen(cmd, "r");
  if (!p) { snprintf(out, cap, "(执行失败)"); return -1; }
  int n = fread(out, 1, cap - 1, p);
  out[n > 0 ? n : 0] = 0;
  return pclose(p);
}

// 把任意文本转成可嵌入 JSON 字符串的形式
static void json_escape(const char *in, char *out, int cap) {
  int o = 0;
  for (const char *p = in; *p && o < cap - 7; p++) {
    unsigned char c = *p;
    if (c == '"' || c == '\\') { out[o++] = '\\'; out[o++] = c; }
    else if (c == '\n') { out[o++] = '\\'; out[o++] = 'n'; }
    else if (c == '\r') continue;
    else if (c == '\t') { out[o++] = '\\'; out[o++] = 't'; }
    else if (c < 0x20) { o += snprintf(out + o, cap - o, "\\u%04x", c); }
    else out[o++] = c;
  }
  out[o] = 0;
}

static void mcp_reply_result(ws_t *ws, int id, const char *result_json) {
  char buf[12288];
  snprintf(buf, sizeof buf,
           "{\"session_id\":\"%s\",\"type\":\"mcp\",\"payload\":"
           "{\"jsonrpc\":\"2.0\",\"id\":%d,\"result\":%s}}",
           g_session, id, result_json);
  ws_send_text(ws, buf);
}

static void mcp_reply_tool_text(ws_t *ws, int id, const char *text, int is_error) {
  char esc[4096], res[5120];
  json_escape(text, esc, sizeof esc);
  snprintf(res, sizeof res,
           "{\"content\":[{\"type\":\"text\",\"text\":\"%s\"}],\"isError\":%s}",
           esc, is_error ? "true" : "false");
  mcp_reply_result(ws, id, res);
}

static const char *MCP_TOOLS =
  "{\"tools\":["
  "{\"name\":\"get_device_status\",\"description\":\"查询 SL1680 设备状态：CPU温度、内存、负载、运行时长、各服务(语音/表情脸/视觉唤醒/时钟)状态\","
  "\"inputSchema\":{\"type\":\"object\",\"properties\":{},\"required\":[]}},"
  "{\"name\":\"set_volume\",\"description\":\"设置喇叭音量。参数 volume 为 0-100 的整数百分比\","
  "\"inputSchema\":{\"type\":\"object\",\"properties\":{\"volume\":{\"type\":\"integer\",\"description\":\"0-100\"}},\"required\":[\"volume\"]}},"
  "{\"name\":\"set_screen_mode\",\"description\":\"切换屏幕显示内容。mode=face 全部屏显示表情脸；mode=clock 显示时钟；mode=camera 副屏显示摄像头实时监控画面(用户说\\\"打开监控/看看摄像头\\\"时用)\","
  "\"inputSchema\":{\"type\":\"object\",\"properties\":{\"mode\":{\"type\":\"string\",\"enum\":[\"face\",\"clock\",\"camera\"]}},\"required\":[\"mode\"]}},"
  "{\"name\":\"set_vision_wake\",\"description\":\"开启或关闭摄像头视觉唤醒(人走近自动打招呼)。参数 enabled 为 true/false\","
  "\"inputSchema\":{\"type\":\"object\",\"properties\":{\"enabled\":{\"type\":\"boolean\"}},\"required\":[\"enabled\"]}},"
  "{\"name\":\"pause_chat\",\"description\":\"暂停语音聊天(闭麦不再听)。用户说\\\"别说话了/闭嘴/安静/停止聊天/退下\\\"等就调用这个。minutes=暂停几分钟，0 表示一直暂停直到有人重新走近\","
  "\"inputSchema\":{\"type\":\"object\",\"properties\":{\"minutes\":{\"type\":\"integer\",\"description\":\"暂停分钟数，0=直到有人走近\"}},\"required\":[\"minutes\"]}}"
  "]}";

static void mcp_do_call(ws_t *ws, int id, const char *msg) {
  char name[64] = "", out[3500], cmd[512];
  json_str(msg, "name", name, sizeof name);
  LOGI("[MCP调用] %s\n", name);

  if (!strcmp(name, "get_device_status")) {
    char t[64] = "?", up[128] = "?", mem[128] = "?", svc[256] = "?";
    run_cmd("cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null", t, sizeof t);
    run_cmd("uptime", up, sizeof up);
    // 单位写全，不然 LLM 会把 446/3959MB 复述成"446GB"
    run_cmd("free -m | awk 'NR==2{print \"已用\"$3\"MB，共\"$2\"MB\"}'", mem, sizeof mem);
    run_cmd("for s in astra-voice dl-face vision-wake dl-clock; do printf '%s:%s ' $s $(systemctl is-active $s 2>/dev/null); done", svc, sizeof svc);
    int mc = atoi(t) / 1000;
    snprintf(out, sizeof out, "CPU温度%d°C；内存%s；%s服务状态: %s", mc, mem, up, svc);
    mcp_reply_tool_text(ws, id, out, 0);
  } else if (!strcmp(name, "set_volume")) {
    int vol = -1;
    json_int(msg, "volume", &vol);
    if (vol < 0 || vol > 100) { mcp_reply_tool_text(ws, id, "音量参数要在0-100之间", 1); return; }
    // USB 声卡控件名不统一，PCM/Speaker/Headphone 挨个试
    snprintf(cmd, sizeof cmd,
             "for ctl in PCM Speaker Headphone Master; do amixer -c Dock sset $ctl %d%% >/dev/null 2>&1 && { echo ok-$ctl; break; }; done; "
             "for ctl in PCM Speaker Headphone Master; do amixer -c Edition sset $ctl %d%% >/dev/null 2>&1 && { echo ok-Edition-$ctl; break; }; done",
             vol, vol);
    run_cmd(cmd, out, sizeof out);
    char msg2[256];
    snprintf(msg2, sizeof msg2, "音量已设为%d%%（%s）", vol, out[0] ? out : "无可调声卡");
    mcp_reply_tool_text(ws, id, msg2, 0);
  } else if (!strcmp(name, "set_screen_mode")) {
    char mode[32] = "";
    json_str(msg, "mode", mode, sizeof mode);
    if (!strcmp(mode, "clock")) {
      run_cmd("systemctl stop dl-face 2>&1; systemctl start dl-clock 2>&1; systemctl is-active dl-clock", out, sizeof out);
      snprintf(cmd, sizeof cmd, "屏幕已切换到时钟(dl-clock: %s)", out);
    } else if (!strcmp(mode, "face")) {
      // 回表情脸：角色文件复位 + 视觉唤醒归还摄像头
      run_cmd("systemctl stop dl-clock 2>&1; echo '1=face' > /tmp/astra_screen_mode.txt; "
              "systemctl start dl-face vision-wake 2>&1; systemctl is-active dl-face", out, sizeof out);
      snprintf(cmd, sizeof cmd, "屏幕已切换到表情脸，视觉唤醒已恢复(dl-face: %s)", out);
    } else if (!strcmp(mode, "camera")) {
      // 监控模式：先停视觉唤醒(它独占摄像头)，再让 dl_face 把副屏切成实况
      run_cmd("systemctl stop dl-clock vision-wake 2>&1; echo '1=camera' > /tmp/astra_screen_mode.txt; "
              "systemctl start dl-face 2>&1; systemctl is-active dl-face", out, sizeof out);
      snprintf(cmd, sizeof cmd, "副屏已切换为摄像头监控画面(注意：监控期间视觉唤醒暂停)(dl-face: %s)", out);
    } else {
      mcp_reply_tool_text(ws, id, "mode 只能是 face/clock/camera", 1);
      return;
    }
    mcp_reply_tool_text(ws, id, cmd, 0);
  } else if (!strcmp(name, "set_vision_wake")) {
    int on = strstr(msg, "true") != NULL;   // arguments 里只有 enabled 一个布尔
    run_cmd(on ? "systemctl start vision-wake 2>&1; systemctl is-active vision-wake"
               : "systemctl stop vision-wake 2>&1; systemctl is-active vision-wake",
            out, sizeof out);
    snprintf(cmd, sizeof cmd, "视觉唤醒已%s(vision-wake: %s)", on ? "开启" : "关闭", out);
    mcp_reply_tool_text(ws, id, cmd, 0);
  } else if (!strcmp(name, "pause_chat")) {
    int mins = 0;
    json_int(msg, "minutes", &mins);
    if (mins < 0) mins = 0;
    if (mins > 1440) mins = 1440;
    g_pause_until = mins ? time(NULL) + (long)mins * 60 : -1;
    write_status("paused");
    if (mins)
      snprintf(out, sizeof out, "好的，接下来 %d 分钟我不会说话，到时间自动恢复；有人走近也会叫醒我", mins);
    else
      snprintf(out, sizeof out, "好的，我先安静了，有人走近时我会重新打招呼");
    mcp_reply_tool_text(ws, id, out, 0);
  } else {
    mcp_reply_tool_text(ws, id, "未知工具", 1);
  }
}

// --text 模式的时序竞态：服务端在 initialize 后 1s 才请求 tools/list，
// 若在此之前就把问题发出去，LLM 手里没有工具，只会凭空瞎答。
// 所以文本问题推迟到 tools/list served 之后再发（见 handle_mcp / main）。
static const char *g_text_once = NULL;
static volatile int g_text_sent = 0;

static void send_text_question(ws_t *ws) {
  if (!g_text_once || g_text_sent) return;
  g_text_sent = 1;
  char msg[MAX_TXT + 128];
  snprintf(msg, sizeof msg,
           "{\"session_id\":\"%s\",\"type\":\"listen\",\"state\":\"detect\",\"text\":\"%s\"}",
           g_session, g_text_once);
  ws_send_text(ws, msg);
}

static void handle_mcp(ws_t *ws, const char *msg) {
  char method[64] = "";
  int id = 0;
  json_str(msg, "method", method, sizeof method);
  json_int(msg, "id", &id);
  LOGV("[MCP] method=%s id=%d\n", method, id);

  if (!strcmp(method, "initialize")) {
    mcp_reply_result(ws, id,
        "{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{\"tools\":{}},"
        "\"serverInfo\":{\"name\":\"sl1680-astra\",\"version\":\"1.0\"}}");
  } else if (!strcmp(method, "tools/list")) {
    mcp_reply_result(ws, id, MCP_TOOLS);
    send_text_question(ws);   // 工具注册完成，现在提问 LLM 才看得见工具
  } else if (!strcmp(method, "tools/call")) {
    mcp_do_call(ws, id, msg);
  } else if (!strcmp(method, "ping")) {
    mcp_reply_result(ws, id, "{}");
  }
  // notifications/* 无需应答
}

// ---------------------------------------------------------------- 协议

static int send_hello(ws_t *ws) {
  return ws_send_text(ws,
      "{\"type\":\"hello\",\"version\":1,\"transport\":\"websocket\","
      "\"features\":{\"mcp\":true},"           // 开启 MCP 设备控制
      "\"audio_params\":{\"format\":\"opus\",\"sample_rate\":16000,"
      "\"channels\":1,\"frame_duration\":60}}");
}

static int send_listen_start(ws_t *ws) {
  char buf[256];
  snprintf(buf, sizeof buf,
           "{\"session_id\":\"%s\",\"type\":\"listen\",\"state\":\"start\",\"mode\":\"auto\"}",
           g_session);
  return ws_send_text(ws, buf);
}

// 视觉唤醒 → 用 detect 文本让 LLM 主动开口（括号提示这是事件不是用户语音）
// 同时它也是"暂停后的复活键"：人走近 → 解除暂停 + 打招呼
static void maybe_greet(void) {
  if (!g_wake) return;
  if (!g_connected) { g_wake = 0; return; }   // 没连上，丢弃
  if (g_speaking) return;                      // 播着呢——保留标志，播完再问候
  g_wake = 0;
  if (g_pause_until != 0) { g_pause_until = 0; LOGI("[暂停] 有人走近，解除暂停\n"); }
  char buf[512];
  snprintf(buf, sizeof buf,
           "{\"session_id\":\"%s\",\"type\":\"listen\",\"state\":\"detect\","
           "\"text\":\"（检测到有客人走近，请你主动热情地打个招呼，一两句即可）\"}",
           g_session);
  ws_send_text(&g_ws, buf);
  LOGI("[视觉唤醒] 触发主动问候\n");
}

// 文本消息分发。返回 1=收到 tts stop（--text 模式用来判断结束）
static int handle_text(const char *msg) {
  char type[32] = "", state[32] = "", text[MAX_TXT];
  json_str(msg, "type", type, sizeof type);

  if (!strcmp(type, "hello")) {
    json_str(msg, "session_id", g_session, sizeof g_session);
    int r;
    // 下行采样率藏在 audio_params 里；扁平搜索 sample_rate 会先撞上我们没发的字段，
    // 但服务端 hello 里只有一个 sample_rate，直接取即可
    if (json_int(msg, "sample_rate", &r) && r > 0 && r != g_dl_rate) {
      g_dl_rate = r;
      if (g_dec) { opus_decoder_destroy(g_dec); g_dec = NULL; }
      if (g_out) { snd_pcm_close(g_out); g_out = NULL; }
    }
    if (!g_dec) { int e; g_dec = opus_decoder_create(g_dl_rate, 1, &e); }
    LOGI("会话建立 session=%.8s… 下行 %dHz\n", g_session, g_dl_rate);
    return 0;
  }
  if (!strcmp(type, "mcp")) {
    handle_mcp(&g_ws, msg);
    return 0;
  }
  if (!strcmp(type, "stt")) {
    if (json_str(msg, "text", text, sizeof text)) {
      snprintf(g_heard, sizeof g_heard, "%s", text);
      g_reply[0] = 0;
      write_status("thinking");   // dl_face 全词比对，缩写不认
      LOGI("[听到] %s\n", text);
    }
    return 0;
  }
  if (!strcmp(type, "llm")) {
    // 表情消息(emotion)，dl_face 目前只认三个字段，先记日志
    if (json_str(msg, "emotion", text, sizeof text)) LOGV("[表情] %s\n", text);
    return 0;
  }
  if (!strcmp(type, "tts")) {
    json_str(msg, "state", state, sizeof state);
    if (!strcmp(state, "start")) {
      g_speaking = 1;
      write_status("speaking");
    } else if (!strcmp(state, "sentence_start")) {
      if (json_str(msg, "text", text, sizeof text)) {
        size_t cur = strlen(g_reply);
        // 服务端分句大多不带标点，句间补顿号，不然字幕全黏成一串
        snprintf(g_reply + cur, sizeof g_reply - cur, "%s%s", cur ? "，" : "", text);
        write_status("speaking");
        LOGI("[回复] %s\n", text);
      }
    } else if (!strcmp(state, "stop")) {
      // 尾音留 300ms 再开麦，防止喇叭余音被采回去
      usleep(300 * 1000);
      g_speaking = 0;
      write_status(chat_paused() ? "paused" : "listening");
      send_listen_start(&g_ws);
      maybe_greet();   // 播报期间攒下的视觉唤醒，现在补上
      return 1;
    }
    return 0;
  }
  LOGV("<- %s\n", msg);
  return 0;
}

// ---------------------------------------------------------------- 主循环

static void usage(const char *a0) {
  fprintf(stderr,
          "用法: %s --server ws://IP:8000/xiaozhi/v1/ [选项]\n"
          "  --dev-in  DEV   采集设备 (默认 plughw:CARD=C920)\n"
          "  --dev-out DEV   播放设备 (默认 plughw:CARD=Edition)\n"
          "  --text  \"...\"   免麦克风：发一句文本，播完回复后退出\n"
          "  --status PATH   状态文件 (默认 /tmp/astra_status.txt，dl_face 读)\n"
          "  -v              详细日志\n", a0);
}

int main(int argc, char **argv) {
  const char *server = NULL, *dev_in = "plughw:CARD=C920";
  const char *text_once = NULL;
  g_dev_out = "plughw:CARD=Edition";
  g_status_path = "/tmp/astra_status.txt";

  for (int i = 1; i < argc; i++) {
    if (!strcmp(argv[i], "--server") && i + 1 < argc) server = argv[++i];
    else if (!strcmp(argv[i], "--dev-in") && i + 1 < argc) dev_in = argv[++i];
    else if (!strcmp(argv[i], "--dev-out") && i + 1 < argc) g_dev_out = argv[++i];
    else if (!strcmp(argv[i], "--text") && i + 1 < argc) text_once = argv[++i];
    else if (!strcmp(argv[i], "--status") && i + 1 < argc) g_status_path = argv[++i];
    else if (!strcmp(argv[i], "-v")) g_verbose = 1;
    else { usage(argv[0]); return 1; }
  }
  if (!server) { usage(argv[0]); return 1; }

  // INT/TERM/USR1 全用 sigaction 且不带 SA_RESTART——glibc signal() 默认自动
  // 重启系统调用，recv 永远醒不来，SIGTERM 就要等 systemd 90 秒后 SIGKILL。
  struct sigaction sa = { 0 };
  sa.sa_handler = on_sigint;
  sigaction(SIGINT, &sa, NULL);
  sigaction(SIGTERM, &sa, NULL);
  sa.sa_handler = on_sigusr1;
  sigaction(SIGUSR1, &sa, NULL);
  srand(time(NULL) ^ getpid());

  // 把 SIGUSR1 圈定在主线程(读循环)：先屏蔽 → 创建采集线程(继承屏蔽) → 主线程再放开
  sigset_t us1;
  sigemptyset(&us1);
  sigaddset(&us1, SIGUSR1);
  pthread_sigmask(SIG_BLOCK, &us1, NULL);

  // device-id 用板子 eth0 MAC，服务端以此区分设备
  char device_id[64] = "sl:16:80:00:00:01";
  FILE *f = fopen("/sys/class/net/eth0/address", "r");
  if (f) {
    if (fscanf(f, "%63s", device_id) != 1) {}
    fclose(f);
  }

  g_heard[0] = g_reply[0] = 0;

  pthread_t cap;
  int cap_started = 0;
  if (!text_once) {
    pthread_create(&cap, NULL, capture_thread, (void *)dev_in);
    cap_started = 1;
  }
  pthread_sigmask(SIG_UNBLOCK, &us1, NULL);   // 主线程接收 SIGUSR1

  int exit_code = 2;
  while (g_run) {
    LOGI("连接 %s …\n", server);
    if (ws_connect(&g_ws, server, device_id)) {
      write_status("offline");
      for (int i = 0; i < 30 && g_run; i++) usleep(100 * 1000);
      if (text_once) break;   // 单发模式不重试太久
      continue;
    }
    send_hello(&g_ws);

    static uint8_t buf[65536];
    size_t len;
    int got_hello = 0, done = 0;
    while (g_run && !done) {
      int op = ws_recv(&g_ws, buf, sizeof buf - 1, &len);
      if (op < 0 || op == 0x8) { LOGI("连接断开\n"); break; }
      if (op == 0x1) {
        buf[len] = 0;
        int stop = handle_text((char *)buf);
        if (!got_hello && g_session[0]) {
          got_hello = 1;
          g_connected = 1;
          write_status("listening");
          if (text_once) {
            g_text_once = text_once;   // 实际发送延迟到 tools/list 之后(见 handle_mcp)
          } else {
            send_listen_start(&g_ws);
          }
        }
        if (stop && text_once) { exit_code = 0; done = 1; }
      } else if (op == 0x2) {
        play_opus(buf, len);
      }
    }
    g_connected = 0;
    close(g_ws.fd);
    if (text_once) break;
    write_status("offline");
    for (int i = 0; i < 30 && g_run; i++) usleep(100 * 1000);   // 3s 重连
  }

  g_run = 0;
  if (cap_started) pthread_join(cap, NULL);
  if (g_out) { snd_pcm_drain(g_out); snd_pcm_close(g_out); }
  if (g_dec) opus_decoder_destroy(g_dec);
  return text_once ? exit_code : 0;
}
