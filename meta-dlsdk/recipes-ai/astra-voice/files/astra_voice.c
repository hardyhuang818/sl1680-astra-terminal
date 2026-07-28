// astra_voice —— SL1680 常驻语音助手
//
// 关键点：VAD / ASR / TTS 三个模型【只在启动时加载一次】。
// 之前用 CLI 每次合成都要重新加载 melo(fp32 170MB)，实测白扔 11.1 秒 —— 这就是为了干掉它。
//
// 链路: ALSA采集 -> Silero VAD -> SenseVoice ASR -> 生成回复 -> VITS TTS -> ALSA播放
//
// 实测依据(2026-07-17, SL1680 4xA73, 均为 4 线程):
//   SenseVoice int8   : RTF 0.197  (int8 比 fp32 快 1.45x、省 3.3x 内存 -> 用 int8)
//   matcha-zh-en      : RTF 0.309  <- 默认。比 melo 快 7 倍，中英双语
//   vits-melo fp32    : RTF 2.139  (int8 比 fp32 还慢 1.9x -> 若用 melo 只能 fp32)
//   A73 = ARMv8.0, 无 dotprod/i8mm；量化收益因模型而异，别照搬
//
// matcha 必须配 vocos-16khz-univ.onnx（官方 README 明确要求）。
// 用 22khz 的也能出声，但实测有吞字（"可以开始"->"可开开始"）。

#include <alsa/asoundlib.h>
#include <math.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "sherpa-onnx/c-api/c-api.h"

#define SR          16000     // 采集/ASR 采样率
#define VAD_WIN     512       // Silero 只在 512/1024/1536 @16k 上训练过，别改
#define READ_CHUNK  1600      // 100ms

static volatile int g_run = 1;
static void on_sigint(int s) { (void)s; g_run = 0; }

// 视觉唤醒：vision_wake 检测到有人靠近时给本进程发 SIGUSR1，
// 处理函数只置标志，实际播欢迎语在主循环里做(信号处理里不能干重活)。
static volatile sig_atomic_t g_wake = 0;
static void on_sigusr1(int s) { (void)s; g_wake = 1; }

// SIGUSR2：外部(如看护 vision_care)让 Astra 播报任意一句话。
// 文本放在 /tmp/astra_say.txt，收到信号后主循环读它并 TTS 播报。
static volatile sig_atomic_t g_say = 0;
static void on_sigusr2(int s) { (void)s; g_say = 1; }

static double now_s(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec + t.tv_nsec / 1e9;
}

// 状态文件：给 DL7400 显示程序读，做实时字幕界面。
// 格式 3 行： STATE / HEARD / REPLY 。原子写(临时文件+rename)避免读到半截。
static const char *g_status_path = NULL;
static void write_status(const char *state, const char *heard, const char *reply) {
  if (!g_status_path) return;
  char tmp[600];
  snprintf(tmp, sizeof tmp, "%s.tmp", g_status_path);
  FILE *f = fopen(tmp, "w");
  if (!f) return;
  fprintf(f, "STATE=%s\nHEARD=%s\nREPLY=%s\n",
          state ? state : "", heard ? heard : "", reply ? reply : "");
  fclose(f);
  rename(tmp, g_status_path);
}

// ---------------------------------------------------------------- ALSA

static snd_pcm_t *open_pcm(const char *dev, snd_pcm_stream_t dir, unsigned rate,
                           unsigned ch) {
  snd_pcm_t *h = NULL;
  int err = snd_pcm_open(&h, dev, dir, 0);
  if (err < 0) {
    fprintf(stderr, "[astra] 打不开 %s (%s): %s\n", dev,
            dir == SND_PCM_STREAM_CAPTURE ? "capture" : "playback",
            snd_strerror(err));
    return NULL;
  }
  unsigned r = rate;
  err = snd_pcm_set_params(h, SND_PCM_FORMAT_S16_LE, SND_PCM_ACCESS_RW_INTERLEAVED,
                           ch, r, 1 /*允许重采样*/, 500000 /*500ms 缓冲*/);
  if (err < 0) {
    fprintf(stderr, "[astra] set_params 失败: %s\n", snd_strerror(err));
    snd_pcm_close(h);
    return NULL;
  }
  return h;
}

// 播放 float[-1,1] 单声道，重采样交给 plughw
static void play(const char *dev, const float *s, int32_t n, int32_t rate) {
  snd_pcm_t *h = open_pcm(dev, SND_PCM_STREAM_PLAYBACK, (unsigned)rate, 1);
  if (!h) return;

  int16_t *buf = (int16_t *)malloc((size_t)n * 2);
  if (!buf) { snd_pcm_close(h); return; }
  for (int32_t i = 0; i < n; ++i) {
    float v = s[i];
    if (v > 1.f) v = 1.f;
    if (v < -1.f) v = -1.f;
    buf[i] = (int16_t)(v * 32767.f);
  }

  int32_t off = 0;
  while (off < n && g_run) {
    snd_pcm_sframes_t w = snd_pcm_writei(h, buf + off, (snd_pcm_uframes_t)(n - off));
    if (w == -EPIPE) {           // underrun：板子上常见，恢复后继续
      snd_pcm_prepare(h);
      continue;
    }
    if (w < 0) {
      w = snd_pcm_recover(h, (int)w, 1);
      if (w < 0) break;
      continue;
    }
    off += (int32_t)w;
  }
  snd_pcm_drain(h);
  snd_pcm_close(h);
  free(buf);
}

// ---------------------------------------------------------------- 回复策略

// 全局 LLM 配置（main 里填）
static const char *g_llm_path = NULL;
static int g_llm_threads = 4;
static const char *g_llm_bin = "/home/voice/bin/llama-completion";

// 事实类问题：用真实数据回答，绝不让 LLM 瞎编（RAG/接地思路，见方案调研 md）。
// 命中返回 1，未命中返回 0。
static int factual_reply(const char *heard, char *out, size_t cap) {
  time_t t = time(NULL); struct tm tm; localtime_r(&t, &tm);

  // 时间 —— 读真实系统时钟
  if (strstr(heard, "几点") || strstr(heard, "时间") || strstr(heard, "几分")) {
    snprintf(out, cap, "现在是%d点%d分。", tm.tm_hour, tm.tm_min);
    return 1;
  }
  // 星期 —— 读真实日期
  if (strstr(heard, "星期") || strstr(heard, "礼拜") || strstr(heard, "周几")) {
    const char *wd[] = {"日","一","二","三","四","五","六"};
    snprintf(out, cap, "今天是星期%s。", wd[tm.tm_wday]);
    return 1;
  }
  // 日期
  if (strstr(heard, "几号") || strstr(heard, "日期") || strstr(heard, "几月")) {
    snprintf(out, cap, "今天是%d月%d号。", tm.tm_mon + 1, tm.tm_mday);
    return 1;
  }
  // 天气 —— 无数据源，诚实说不知道，绝不编（这正是之前"晴朗气温适宜"幻觉的根源）
  if (strstr(heard, "天气") || strstr(heard, "气温") || strstr(heard, "下雨") ||
      strstr(heard, "温度") || strstr(heard, "冷不冷") || strstr(heard, "热不热")) {
    snprintf(out, cap, "我现在没有联网，查不到实时天气，抱歉。");
    return 1;
  }
  return 0;
}

// 规则回复：没有 LLM 时的最后兜底
static void rule_reply(const char *heard, char *out, size_t cap) {
  if (!heard || !*heard) { snprintf(out, cap, "我没有听清，请再说一遍。"); return; }
  if (strstr(heard, "你好") || strstr(heard, "您好"))
    snprintf(out, cap, "你好，我是 Astra，很高兴见到你。");
  else if (strstr(heard, "再见") || strstr(heard, "拜拜"))
    snprintf(out, cap, "再见，期待下次见面。");
  else
    snprintf(out, cap, "你说的是：%s", heard);
}

// 转义 shell 单引号（把 ' 换成 '\'' ）
static void sh_quote(const char *in, char *out, size_t cap) {
  size_t j = 0;
  if (j < cap) out[j++] = '\'';
  for (const char *p = in; *p && j + 4 < cap; ++p) {
    if (*p == '\'') { out[j++]='\''; out[j++]='\\'; out[j++]='\''; out[j++]='\''; }
    else out[j++] = *p;
  }
  if (j < cap) out[j++] = '\'';
  out[j < cap ? j : cap - 1] = 0;
}

// 云端 LLM：调 python 助手(它用 urllib 发 HTTPS，处理所有 JSON)。
// key 从环境变量 DEEPSEEK_API_KEY 读(systemd EnvironmentFile 注入)，代码里没有 key。
// 失败(无网/超时/无key/解析错) → python 退出非0 → 这里回 0 → 调用方回落本地。
static int g_cloud = 0;
static int cloud_reply(const char *heard, char *out, size_t cap) {
  if (!g_cloud) return 0;
  char q[1024];
  sh_quote(heard, q, sizeof q);   // 这里 sh_quote 是对的：给 python 传一个 shell 参数
  char cmd[2048];
  snprintf(cmd, sizeof cmd, "python3 /home/voice/astra_llm.py %s 2>/dev/null", q);
  FILE *fp = popen(cmd, "r");
  if (!fp) return 0;
  size_t n = 0; int c;
  while ((c = fgetc(fp)) != EOF && n + 1 < cap) {
    if (c == '\n' || c == '\r') c = ' ';
    out[n++] = (char)c;
  }
  out[n] = 0;
  int rc = pclose(fp);
  while (*out == ' ') memmove(out, out + 1, strlen(out));
  size_t L = strlen(out);
  while (L > 0 && out[L-1] == ' ') out[--L] = 0;
  // python 成功时退出 0 且有输出；只要非空就算成功
  (void)rc;
  return L > 0;
}

// 合成并播放一句话(用于事实/本地/规则的单句回复)
static const SherpaOnnxOfflineTts *g_tts = NULL;
static const char *g_dev_out = NULL;
static void speak_once(const char *text) {
  if (!g_tts || !text || !*text) return;
  const SherpaOnnxGeneratedAudio *a = SherpaOnnxOfflineTtsGenerate(g_tts, text, 0, 1.0f);
  if (a) { play(g_dev_out, a->samples, a->n, a->sample_rate);
           SherpaOnnxDestroyOfflineTtsGeneratedAudio(a); }
}

// ★流式提速：云端 LLM 边生成边按句返回，每来一句立刻合成播放，不等整段。
// 播第 1 句时，LLM 还在生成后面的句子(流进管道缓冲) → 用户更早听到声音。
// fullreply 累积完整文本(给状态/字幕显示)。有任何一句=成功返回1，否则0(回落)。
static int speak_cloud_stream(const char *heard, char *fullreply, size_t cap) {
  if (!g_cloud) return 0;
  char q[1024];
  sh_quote(heard, q, sizeof q);
  char cmd[2048];
  snprintf(cmd, sizeof cmd, "python3 /home/voice/astra_llm.py --stream %s 2>/dev/null", q);
  FILE *fp = popen(cmd, "r");
  if (!fp) return 0;
  char line[1024];
  int got = 0;
  fullreply[0] = 0;
  while (fgets(line, sizeof line, fp)) {
    char *nl = strchr(line, '\n'); if (nl) *nl = 0;
    if (!*line) continue;
    got = 1;
    size_t fl = strlen(fullreply);
    if (fl < cap - 1) snprintf(fullreply + fl, cap - fl, "%s", line);  // 累积
    write_status("speaking", heard, fullreply);
    speak_once(line);   // ★这一句立刻播；下一句在此期间已流进管道
  }
  pclose(fp);
  return got;
}

// 用 llama-completion 子进程生成回复。失败则回 0，调用方退回规则。
static int llm_reply(const char *heard, char *out, size_t cap) {
  if (!g_llm_path) return 0;

  char q[1024];
  sh_quote(heard, q, sizeof q);

  // Qwen2.5 的 chatml 模板；system 约束简短中文，避免小模型跑题
  char cmd[4096];
  snprintf(cmd, sizeof cmd,
    "%s -m %s -t %d -c 1024 -n 80 --no-warmup --no-display-prompt -no-cnv "
    "-p '<|im_start|>system\n你是Astra语音助手，用一到两句简短的中文口语回答，"
    "不要用表情符号，不要换行。你没有联网，不知道实时天气、新闻、股价等信息；"
    "遇到你不确定或需要实时数据的问题，直接说不知道，绝对不要编造具体数字或事实。"
    "<|im_end|>\n<|im_start|>user\n'%s'<|im_end|>\n"
    "<|im_start|>assistant\n' 2>/dev/null",
    g_llm_bin, g_llm_path, g_llm_threads, q);

  FILE *fp = popen(cmd, "r");
  if (!fp) return 0;

  size_t n = 0; int c;
  while ((c = fgetc(fp)) != EOF && n + 1 < cap) {
    if (c == '\n' || c == '\r') c = ' ';   // TTS 不吃换行
    out[n++] = (char)c;
  }
  out[n] = 0;
  pclose(fp);

  // 去掉模型可能吐出的结束标记和首尾空格
  char *e;
  if ((e = strstr(out, "<|im_end|>"))) *e = 0;
  if ((e = strstr(out, "[end of text]"))) *e = 0;
  while (*out == ' ') memmove(out, out + 1, strlen(out));
  size_t L = strlen(out);
  while (L > 0 && (out[L-1] == ' ')) out[--L] = 0;

  return L > 0;   // 空回复视为失败
}

static void make_reply(const char *heard, char *out, size_t cap) {
  if (!heard || !*heard) { snprintf(out, cap, "我没有听清，请再说一遍。"); return; }
  // ★顺序很关键：事实类(时间/日期/天气)先用真实数据，绝不让 LLM 幻觉。
  if (factual_reply(heard, out, cap)) return;
  if (cloud_reply(heard, out, cap)) return;               // ①云端 LLM(联网,更聪明更快)
  if (g_llm_path && llm_reply(heard, out, cap)) return;   // ②断网回落本地 LLM
  rule_reply(heard, out, cap);                            // ③最后兜底
}

// ---------------------------------------------------------------- main

static void usage(const char *p) {
  fprintf(stderr,
          "用法: %s [选项]\n"
          "  --dir DIR        模型根目录 (默认 /home/voice)\n"
          "  --dev NAME       ALSA 设备，同时用于采集和播放 (默认 plughw:2,0)\n"
          "  --dev-in NAME    仅采集设备(麦克风)，如 C920=plughw:3,0；覆盖 --dev\n"
          "  --dev-out NAME   仅播放设备(喇叭)，C920无喇叭时必须单独指定；覆盖 --dev\n"
          "  --threads N      推理线程 (默认 4)\n"
          "  --vad-threshold F  VAD 阈值 (默认 0.5)\n"
          "  --greet 0|1      启动时是否播报欢迎语 (默认 1)\n"
          "  --tts matcha|melo  TTS 后端 (默认 matcha, RTF 0.309; melo 为 2.139)\n"
          "  --lang auto|zh|en  SenseVoice 语种 (默认 auto)\n"
          "  --save-dir DIR   把每段语音存成 wav，便于事后复盘（默认不存）\n"
          "  --min-rms N      低于此音量的段直接丢弃，挡住噪声误触发 (默认 150)\n"
          "  --min-dur S      短于此时长的段直接丢弃 (默认 0.4)\n"
          "  --gain F         采集软件增益，麦克风电平偏低时放大 (默认 1.0)\n"
          "  --pad-front S    送ASR前给语音段前面补的静音秒数，修复VAD削头 (默认 0.3)\n"
          "  --pad-back S     语音段后面补的静音秒数 (默认 0.1)\n"
          "  --llm PATH       gguf 模型路径，给出则用 LLM 生成回复（否则用内置规则）\n"
          "  --llm-threads N  LLM 线程 (默认 4)\n"
          "  --status FILE    把状态/文字写到此文件，供 DL7400 显示程序做实时字幕\n"
          "  --cloud          启用云端 LLM(需环境变量 DEEPSEEK_API_KEY)；失败自动回落本地\n",
          p);
}

int main(int argc, char **argv) {
  const char *dir = "/home/voice";
  const char *dev = "plughw:2,0";      // 兼容旧用法：同时设采集和播放
  const char *dev_in = NULL;           // 采集设备（麦克风），如 C920 = plughw:3,0
  const char *dev_out = NULL;          // 播放设备（喇叭），C920 无喇叭时必须分开
  const char *tts_kind = "matcha";
  const char *lang = "zh";   // auto 会把短噪声段误判成日语("だな")；产品是中英为主，默认 zh
  const char *save_dir = NULL;
  const char *llm_path = NULL;
  int threads = 4;
  int llm_threads = 4;
  int min_rms = 150;      // 实测：说话 RMS~250-400，噪声~30；900 太高会挡住真实语音
  double min_dur = 0.4;
  float gain = 1.0f;
  float vad_th = 0.5f;
  double pad_front = 0.2; // ★VAD 削掉开头清辅音，前补静音修复。CER实测 0.2/0.2 优于 0.3/0.1
  double pad_back = 0.2;
  int greet = 1;

  for (int i = 1; i < argc; ++i) {
    if (!strcmp(argv[i], "--dir") && i + 1 < argc)            dir = argv[++i];
    else if (!strcmp(argv[i], "--dev") && i + 1 < argc)       dev = argv[++i];
    else if (!strcmp(argv[i], "--dev-in") && i + 1 < argc)    dev_in = argv[++i];
    else if (!strcmp(argv[i], "--dev-out") && i + 1 < argc)   dev_out = argv[++i];
    else if (!strcmp(argv[i], "--threads") && i + 1 < argc)   threads = atoi(argv[++i]);
    else if (!strcmp(argv[i], "--vad-threshold") && i+1<argc) vad_th = (float)atof(argv[++i]);
    else if (!strcmp(argv[i], "--greet") && i + 1 < argc)     greet = atoi(argv[++i]);
    else if (!strcmp(argv[i], "--tts") && i + 1 < argc)       tts_kind = argv[++i];
    else if (!strcmp(argv[i], "--lang") && i + 1 < argc)      lang = argv[++i];
    else if (!strcmp(argv[i], "--save-dir") && i + 1 < argc)  save_dir = argv[++i];
    else if (!strcmp(argv[i], "--min-rms") && i + 1 < argc)   min_rms = atoi(argv[++i]);
    else if (!strcmp(argv[i], "--min-dur") && i + 1 < argc)   min_dur = atof(argv[++i]);
    else if (!strcmp(argv[i], "--gain") && i + 1 < argc)      gain = (float)atof(argv[++i]);
    else if (!strcmp(argv[i], "--pad-front") && i+1 < argc)   pad_front = atof(argv[++i]);
    else if (!strcmp(argv[i], "--pad-back") && i + 1 < argc)  pad_back = atof(argv[++i]);
    else if (!strcmp(argv[i], "--llm") && i + 1 < argc)       llm_path = argv[++i];
    else if (!strcmp(argv[i], "--llm-threads") && i+1 < argc) llm_threads = atoi(argv[++i]);
    else if (!strcmp(argv[i], "--status") && i + 1 < argc)    g_status_path = argv[++i];
    else if (!strcmp(argv[i], "--cloud"))                     g_cloud = 1;
    else if (!strcmp(argv[i], "--test-reply") && i+1 < argc) {
      // 离线自测回复逻辑：不启动音频，直接对一句文本走 make_reply 并打印
      g_llm_path = llm_path; g_llm_threads = llm_threads;
      char r[1024];
      make_reply(argv[++i], r, sizeof r);
      printf("%s\n", r);
      return 0;
    }
    else { usage(argv[0]); return 1; }
  }
  int use_matcha = !strcmp(tts_kind, "matcha");
  int seg_no = 0;
  // 采集/播放设备：优先用 --dev-in/--dev-out，否则回落到 --dev
  if (!dev_in)  dev_in = dev;
  if (!dev_out) dev_out = dev;

  // 把 LLM 配置交给回复函数
  g_llm_path = llm_path;
  g_llm_threads = llm_threads;

  signal(SIGINT, on_sigint);
  signal(SIGTERM, on_sigint);
  signal(SIGUSR1, on_sigusr1);   // 视觉唤醒：vision_wake 发来
  signal(SIGUSR2, on_sigusr2);   // 播报任意告警：vision_care 发来
  setvbuf(stdout, NULL, _IOLBF, 0);   // 行缓冲：systemd journal 里能实时看到

  char p_vad[512], p_asr[512], p_tok[512];
  char p_am[512], p_voc[512], p_lex[512], p_ttok[512], p_data[512], p_fst[512];
  snprintf(p_vad, sizeof p_vad, "%s/sv/silero_vad.onnx", dir);
  snprintf(p_asr, sizeof p_asr, "%s/sv/model.int8.onnx", dir);
  snprintf(p_tok, sizeof p_tok, "%s/sv/tokens.txt", dir);

  if (use_matcha) {
    snprintf(p_am,   sizeof p_am,   "%s/matcha/model-steps-3.onnx", dir);
    snprintf(p_voc,  sizeof p_voc,  "%s/matcha/vocos-16khz-univ.onnx", dir);  // 必须 16k
    snprintf(p_lex,  sizeof p_lex,  "%s/matcha/lexicon.txt", dir);
    snprintf(p_ttok, sizeof p_ttok, "%s/matcha/tokens.txt", dir);
    snprintf(p_data, sizeof p_data, "%s/matcha/espeak-ng-data", dir);
    snprintf(p_fst,  sizeof p_fst,  "%s/matcha/date-zh.fst,%s/matcha/number-zh.fst", dir, dir);
  } else {
    snprintf(p_am,   sizeof p_am,   "%s/tts/model.onnx", dir);   // fp32：int8 实测更慢
    snprintf(p_lex,  sizeof p_lex,  "%s/tts/lexicon.txt", dir);
    snprintf(p_ttok, sizeof p_ttok, "%s/tts/tokens.txt", dir);
    snprintf(p_fst,  sizeof p_fst,  "%s/tts/date.fst,%s/tts/number.fst", dir, dir);
  }

  double t0 = now_s();
  printf("[astra] 加载模型（只此一次）...\n");

  // --- VAD ---
  SherpaOnnxVadModelConfig vc;
  memset(&vc, 0, sizeof vc);
  vc.silero_vad.model = p_vad;
  vc.silero_vad.threshold = vad_th;
  vc.silero_vad.min_silence_duration = 0.6f;
  vc.silero_vad.min_speech_duration = 0.25f;
  vc.silero_vad.max_speech_duration = 12.0f;
  vc.silero_vad.window_size = VAD_WIN;
  vc.sample_rate = SR;
  vc.num_threads = 1;
  vc.provider = "cpu";
  const SherpaOnnxVoiceActivityDetector *vad =
      SherpaOnnxCreateVoiceActivityDetector(&vc, 30.0f);
  if (!vad) { fprintf(stderr, "[astra] VAD 创建失败\n"); return 1; }

  // --- ASR (SenseVoice int8) ---
  SherpaOnnxOfflineRecognizerConfig rc;
  memset(&rc, 0, sizeof rc);
  rc.feat_config.sample_rate = SR;
  rc.feat_config.feature_dim = 80;
  rc.model_config.sense_voice.model = p_asr;
  rc.model_config.sense_voice.language = lang;   // auto 会把短句误判成日语("だな")
  rc.model_config.sense_voice.use_itn = 1;
  rc.model_config.tokens = p_tok;
  rc.model_config.num_threads = threads;
  rc.model_config.provider = "cpu";
  rc.model_config.debug = 0;
  rc.decoding_method = "greedy_search";
  const SherpaOnnxOfflineRecognizer *asr = SherpaOnnxCreateOfflineRecognizer(&rc);
  if (!asr) { fprintf(stderr, "[astra] ASR 创建失败\n"); return 1; }

  // --- TTS ---
  SherpaOnnxOfflineTtsConfig tc;
  memset(&tc, 0, sizeof tc);
  if (use_matcha) {
    tc.model.matcha.acoustic_model = p_am;
    tc.model.matcha.vocoder = p_voc;
    tc.model.matcha.lexicon = p_lex;
    tc.model.matcha.tokens = p_ttok;
    tc.model.matcha.data_dir = p_data;
    tc.model.matcha.noise_scale = 0.667f;
    tc.model.matcha.length_scale = 1.0f;
  } else {
    tc.model.vits.model = p_am;
    tc.model.vits.lexicon = p_lex;
    tc.model.vits.tokens = p_ttok;
    tc.model.vits.noise_scale = 0.667f;
    tc.model.vits.noise_scale_w = 0.8f;
    tc.model.vits.length_scale = 1.0f;
  }
  tc.model.num_threads = threads;
  tc.model.provider = "cpu";
  tc.model.debug = 0;
  tc.rule_fsts = p_fst;
  tc.max_num_sentences = 1;
  const SherpaOnnxOfflineTts *tts = SherpaOnnxCreateOfflineTts(&tc);
  if (!tts) { fprintf(stderr, "[astra] TTS 创建失败\n"); return 1; }
  g_tts = tts; g_dev_out = dev_out;   // 给 speak_once/speak_cloud_stream 用

  printf("[astra] 模型就绪，耗时 %.1f 秒 (TTS=%s, LLM=%s)。此后不再加载。\n",
         now_s() - t0, tts_kind, llm_path ? llm_path : "规则");

  if (greet) {
    const char *g = "你好，我是 Astra，请开始说话。";
    write_status("speaking", "", g);
    double tg = now_s();
    const SherpaOnnxGeneratedAudio *a = SherpaOnnxOfflineTtsGenerate(tts, g, 0, 1.0f);
    if (a) {
      double gen = now_s() - tg;
      double out = a->n / (double)a->sample_rate;
      // 这是【热】TTS：模型已在内存，此处不含加载
      printf("[机器] %s   (TTS %.2fs -> 音频 %.2fs, RTF %.2f)\n",
             g, gen, out, gen / (out > 0 ? out : 1));
      play(dev_out, a->samples, a->n, a->sample_rate);
      SherpaOnnxDestroyOfflineTtsGeneratedAudio(a);
    }
  }

  snd_pcm_t *cap = open_pcm(dev_in, SND_PCM_STREAM_CAPTURE, SR, 1);
  if (!cap) return 1;

  write_status("listening", "", "");
  printf("[astra] ★开始监听（Ctrl+C 退出）\n");

  int16_t  raw[READ_CHUNK];
  float    fbuf[READ_CHUNK];
  char     reply[1024];

  double wake_last = 0;   // 唤醒冷却，避免一直有人时反复播欢迎语
  while (g_run) {
    // 视觉唤醒：有人靠近 → 播欢迎语（10 秒冷却内不重复）
    if (g_wake) {
      g_wake = 0;
      double tnow = now_s();
      if (tnow - wake_last > 10.0) {
        wake_last = tnow;
        const char *w = "你好，欢迎，有什么可以帮你的吗？";
        write_status("speaking", "", w);
        printf("[唤醒] 检测到有人靠近，播欢迎语\n");
        speak_once(w);
        write_status("listening", "", "");
        snd_pcm_drop(cap); snd_pcm_prepare(cap);   // 丢掉播放期录入
      }
    }
    // 看护告警：读 /tmp/astra_say.txt 并播报（vision_care 触发）
    if (g_say) {
      g_say = 0;
      FILE *sf = fopen("/tmp/astra_say.txt", "r");
      if (sf) {
        char msg[512];
        if (fgets(msg, sizeof msg, sf)) {
          char *nl = strchr(msg, '\n'); if (nl) *nl = 0;
          if (*msg) {
            write_status("speaking", "", msg);
            printf("[播报] %s\n", msg);
            speak_once(msg);
            write_status("listening", "", "");
            snd_pcm_drop(cap); snd_pcm_prepare(cap);
          }
        }
        fclose(sf);
      }
    }

    snd_pcm_sframes_t got = snd_pcm_readi(cap, raw, READ_CHUNK);
    if (got == -EPIPE) { snd_pcm_prepare(cap); continue; }
    if (got < 0) {
      got = snd_pcm_recover(cap, (int)got, 1);
      if (got < 0) break;
      continue;
    }
    for (snd_pcm_sframes_t i = 0; i < got; ++i) {
      float v = raw[i] / 32768.0f * gain;   // 软件增益：麦克风电平偏低时拉起来
      if (v > 1.f) v = 1.f;                  // 削波保护
      if (v < -1.f) v = -1.f;
      fbuf[i] = v;
    }
    SherpaOnnxVoiceActivityDetectorAcceptWaveform(vad, fbuf, (int32_t)got);

    while (!SherpaOnnxVoiceActivityDetectorEmpty(vad) && g_run) {
      const SherpaOnnxSpeechSegment *seg = SherpaOnnxVoiceActivityDetectorFront(vad);

      // 能量门限：VAD 会被环境噪声触发，ASR 再对着噪声硬解出「あ」「日起40」这种东西。
      // 实测(58段)：认对的 RMS 1238~1488，糊掉的 481~683。
      // 注意 RMS 不是干净的分界（873 好 / 876 坏都有），所以门限设得保守，只挡明显的噪声。
      double acc = 0;
      for (int32_t i = 0; i < seg->n; ++i) acc += (double)seg->samples[i] * seg->samples[i];
      int rms = (int)(sqrt(acc / (seg->n > 0 ? seg->n : 1)) * 32768);
      double sdur = seg->n / (double)SR;

      if (rms < min_rms || sdur < min_dur) {
        printf("[跳过] 太轻/太短 (RMS=%d < %d, %.2fs)\n", rms, min_rms, sdur);
        SherpaOnnxDestroySpeechSegment(seg);
        SherpaOnnxVoiceActivityDetectorPop(vad);
        continue;
      }

      double ta = now_s();
      // ★关键修复：VAD 会削掉句子开头的清辅音（如"今"的 j），SenseVoice 拿到残缺开头就糊字。
      // PC 对照实验证明：仅在【前面】补静音就能把"看这怎么样"还原成"今天天气怎么样"。
      // 补的是零(静音)即可，不必真实音频。前 0.3s 最有效，后补少量。
      int32_t pf = (int32_t)(pad_front * SR);
      int32_t pb = (int32_t)(pad_back * SR);
      int32_t pn = pf + seg->n + pb;
      float *padded = (float *)malloc((size_t)pn * sizeof(float));
      const float *asr_in = seg->samples;
      int32_t asr_n = seg->n;
      if (padded) {
        for (int32_t i = 0; i < pf; ++i) padded[i] = 0.f;
        memcpy(padded + pf, seg->samples, (size_t)seg->n * sizeof(float));
        for (int32_t i = 0; i < pb; ++i) padded[pf + seg->n + i] = 0.f;
        asr_in = padded; asr_n = pn;
      }
      const SherpaOnnxOfflineStream *st = SherpaOnnxCreateOfflineStream(asr);
      SherpaOnnxAcceptWaveformOffline(st, SR, asr_in, asr_n);
      SherpaOnnxDecodeOfflineStream(asr, st);
      const SherpaOnnxOfflineRecognizerResult *res = SherpaOnnxGetOfflineStreamResult(st);
      free(padded);

      double dur = seg->n / (double)SR;
      double asr_s = now_s() - ta;
      const char *heard = (res && res->text) ? res->text : "";

      // 存下原始语音段：识别错了才有据可查，不然只能靠猜
      if (save_dir) {
        char wp[600];
        snprintf(wp, sizeof wp, "%s/seg_%03d.wav", save_dir, ++seg_no);
        SherpaOnnxWriteWave(seg->samples, seg->n, SR, wp);
        printf("[存 ] %s\n", wp);
      }

      printf("[你 ] %s   (语音 %.1fs, ASR %.2fs, RTF %.2f)\n",
             heard, dur, asr_s, asr_s / (dur > 0 ? dur : 1));

      if (*heard) {
        write_status("thinking", heard, "");   // 听到了，正在想
        double tb = now_s();
        // 回复分级：事实类 → 云端【流式】→ 本地 → 规则。只有云端走流式(边生成边播)。
        if (factual_reply(heard, reply, sizeof reply)) {
          write_status("speaking", heard, reply);
          speak_once(reply);
        } else if (speak_cloud_stream(heard, reply, sizeof reply)) {
          // 流式内部已边合成边播；reply 累积了完整文本(给日志/字幕)
        } else if (g_llm_path && llm_reply(heard, reply, sizeof reply)) {
          write_status("speaking", heard, reply);
          speak_once(reply);
        } else {
          rule_reply(heard, reply, sizeof reply);
          write_status("speaking", heard, reply);
          speak_once(reply);
        }
        printf("[机器] %s   (总 %.2fs)\n", reply, now_s() - tb);
        // 放音期间会把自己说的话录进去 → 丢掉这段避免自问自答(权宜之计，正解是 AEC)
        snd_pcm_drop(cap);
        snd_pcm_prepare(cap);
        write_status("listening", "", "");     // 说完，回到监听
      }

      SherpaOnnxDestroyOfflineRecognizerResult(res);
      SherpaOnnxDestroyOfflineStream(st);
      SherpaOnnxDestroySpeechSegment(seg);
      SherpaOnnxVoiceActivityDetectorPop(vad);
    }
  }

  printf("\n[astra] 退出中...\n");
  snd_pcm_close(cap);
  SherpaOnnxDestroyOfflineTts(tts);
  SherpaOnnxDestroyOfflineRecognizer(asr);
  SherpaOnnxDestroyVoiceActivityDetector(vad);
  return 0;
}
