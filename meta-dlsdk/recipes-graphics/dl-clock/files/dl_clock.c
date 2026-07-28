// dl_clock.c — DL7400 时钟 + 跑马灯，开机自动运行，支持【多屏同时点亮】
//
// 为什么这个场景适合 DisplayLink：
//   DL3+ 是【按变化区域压缩】的。时钟只有数字在变、跑马灯只有一条带在动，
//   帧间差异极小 -> 传输量很低 -> 流畅。
//   (对比：全屏视频每帧全变，实测只有 7.4fps)
//
// 用法:
//   dl_clock                     【所有】接上的屏一起点亮(默认)
//   dl_clock --screen 0          只点第 0 个屏
//   dl_clock --text "自定义"      跑马灯文字(不给则每屏显示【自己的】EDID 信息)
//   dl_clock --fps 15            刷新率(默认 15)
//   dl_clock --speed 15          跑马灯速度，【字/秒】(默认 15；越小越慢，如 5)
//   dl_clock --max-hz 60         模式刷新率上限(默认 60)。★不盲从 preferred_mode★
//                                实测 Mi Monitor 的 preferred 是 4K@160Hz，DL7400+USB3
//                                喂不动 -> 链路永久阻塞(死卡 7 帧)。限到 60Hz 就正常。
//   dl_clock --wait              找不到设备时【等待】而不是退出(开机自启用)
//
// 每个屏默认显示【它自己的】身份信息(从 EDID 解析)：
//   显示器名 / 厂商(PnP ID) / 产品码 / 分辨率@刷新率 / 接在 DL7400 哪个输出口
//
// 设计要点:
//   * 每个屏一条独立 GStreamer 管线 + 独立线程，互不阻塞
//     (不能共用：各屏分辨率不同，如 1080p + 4K，字号/窗口宽度都要各自算)
//   * --wait: 开机时 DL7400 可能还没枚举好，循环等待 + 热插拔自恢复
//   * 收到 SIGINT/SIGTERM 干净 teardown(否则设备会卡死，只能 usb unbind/bind 复位)
//
// 编译: gcc dl_clock.c $(pkg-config --cflags --libs gstreamer-1.0 gstreamer-app-1.0) -ldlsdk -lusb-1.0 -lm -o dl_clock

#include "dlsdk/dlsdk.h"
#include <gst/gst.h>
#include <gst/app/gstappsink.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <unistd.h>
#include <time.h>

#define MAX_SCREENS 8

static volatile sig_atomic_t g_stop = 0;
static void on_sig(int s) { (void)s; g_stop = 1; }

static const char* FW_DIR = "/usr/share/displaylink/DL-firmware";

static double now_sec(void) {
  struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
  return ts.tv_sec + ts.tv_nsec / 1e9;
}

// ---- 从 EDID 里解析出这台屏的身份信息 ----
// EDID 1.3/1.4 结构(前 128 字节)：
//   [0..7]   固定头 00 FF FF FF FF FF FF 00
//   [8..9]   厂商 PnP ID(3 个字母压在 15 bit 里，每个 5 bit，'A'=1)
//   [10..11] 产品码(小端)
//   [18..19] EDID 版本.修订
//   [54..125] 4 个 18 字节 descriptor；tag 0xFC = 显示器名
typedef struct {
  char name[16];      // 显示器名(FC descriptor)
  char vendor[4];     // 厂商 3 字母
  unsigned product;   // 产品码
  int  ver, rev;      // EDID 版本
  int  valid;
} edid_info_t;

static void parse_edid(const uint8_t* e, uint32_t len, edid_info_t* o) {
  memset(o, 0, sizeof(*o));
  if (!e || len < 128) return;
  // 头必须匹配，否则读到的是垃圾
  static const uint8_t hdr[8] = {0x00,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0x00};
  if (memcmp(e, hdr, 8) != 0) return;
  o->valid = 1;

  unsigned m = (e[8] << 8) | e[9];
  o->vendor[0] = (char)(((m >> 10) & 0x1F) + 'A' - 1);
  o->vendor[1] = (char)(((m >> 5)  & 0x1F) + 'A' - 1);
  o->vendor[2] = (char)(( m        & 0x1F) + 'A' - 1);
  o->vendor[3] = '\0';
  o->product = (unsigned)(e[10] | (e[11] << 8));
  o->ver = e[18]; o->rev = e[19];

  // 找 0xFC descriptor = 显示器名
  for (int b = 54; b <= 108; b += 18) {
    if (e[b]==0 && e[b+1]==0 && e[b+2]==0 && e[b+3]==0xFC) {
      int k = 0;
      for (int i = 5; i < 18 && k < (int)sizeof(o->name) - 1; ++i) {
        char c = (char)e[b+i];
        if (c == 0x0A) break;          // EDID 用 0x0A 结束字符串
        if (c < 32 || c > 126) continue;
        o->name[k++] = c;
      }
      // 去掉尾部空格
      while (k > 0 && o->name[k-1] == ' ') k--;
      o->name[k] = '\0';
      break;
    }
  }
  if (o->name[0] == '\0') snprintf(o->name, sizeof(o->name), "Unknown");
}

// 从 display id 末尾的 "^N" 取出 DL7400 的物理输出口号
static int port_of(const char* id) {
  const char* p = id ? strrchr(id, '^') : NULL;
  return p ? atoi(p + 1) : -1;
}

// ---- 挑一个实际能驱动的模式 ----
// 为什么不能盲从 preferred_mode：
//   实测 Mi Monitor 的 preferred 是 3840x2160@【160Hz】。DL7400 的输出能力 +
//   SL1680 的 USB3(5Gbps) 根本喂不动这个模式 -> dlsdk_display_show/wait_on_show
//   推几帧后【永久阻塞】(实测死卡在 7 帧，帧数计数器彻底冻结)。
//   而同为 4K 的 Redmi 报 @60Hz，一直稳定 8.7fps。
// 策略：在 EDID 模式表里挑【分辨率与 preferred 相同、刷新率 <= max_hz 的最高刷新率】。
//   找不到就退回 preferred。
static int pick_mode(dlsdk_display_handle d, unsigned max_hz, dlsdk_display_mode* out) {
  dlsdk_display_mode pref; memset(&pref, 0, sizeof(pref));
  if (dlsdk_display_preferred_mode(d, &pref) != DLSDK_SUCCESS) return -1;
  *out = pref;
  if (pref.refreshRateHz <= max_hz) return 0;      // preferred 本来就没超，直接用

  unsigned int mc = 0;
  if (dlsdk_display_modes(d, NULL, &mc) != DLSDK_SUCCESS || mc == 0 || mc > 512) return 0;
  dlsdk_display_mode* ms = malloc(sizeof(dlsdk_display_mode) * mc);
  if (!ms) return 0;
  if (dlsdk_display_modes(d, ms, &mc) == DLSDK_SUCCESS) {
    int best = -1;
    for (unsigned k = 0; k < mc; ++k) {
      if (ms[k].resolution.width  != pref.resolution.width)  continue;  // 保持同分辨率
      if (ms[k].resolution.height != pref.resolution.height) continue;
      if (ms[k].refreshRateHz > max_hz) continue;
      if (best < 0 || ms[k].refreshRateHz > ms[best].refreshRateHz) best = (int)k;
    }
    if (best >= 0) {
      *out = ms[best];
      fprintf(stderr, "[dl_clock] preferred %ux%u@%uHz 超过上限 %uHz -> 改用 %ux%u@%uHz\n",
              pref.resolution.width, pref.resolution.height, pref.refreshRateHz, max_hz,
              out->resolution.width, out->resolution.height, out->refreshRateHz);
    }
  }
  free(ms);
  return 0;
}

// 每个屏一份独立上下文
typedef struct {
  int idx;                     // 屏号
  dlsdk_display_handle disp;
  unsigned w, h;
  uint32_t* buf;
  long frames;
  double t0;

  // ---- 这台屏的身份(从 EDID 解析 + display id) ----
  char name[16];               // 显示器名，如 "Redmi 27 NU"
  char vendor[4];              // 厂商 PnP ID，如 "XMI"
  unsigned product;            // 产品码
  unsigned hz;                 // 实际生效的刷新率
  int port;                    // DL7400 物理输出口号(display id 里的 ^N)

  GstElement* pipe;
  GstElement* marquee;

  // 跑马灯用【滚动字符串】实现（经典 LED 跑马灯做法）：
  //   textoverlay 的 xpos 只接受 [0,1]，无法移出屏幕左边 -> 不能靠动 xpos 滚动。
  //   改为固定位置、按【字/秒】把字符串向左转。配等宽字体(Liberation Mono)效果平滑。
  gchar* mq_ring;
  glong  mq_len, mq_off, mq_win;
  double mq_cps, mq_last;
} screen_t;

// 每来一帧：推给该屏 + 滚动它自己的跑马灯
static GstFlowReturn on_sample(GstAppSink* sink, gpointer user) {
  screen_t* s = (screen_t*)user;
  GstSample* smp = gst_app_sink_pull_sample(sink);
  if (!smp) return GST_FLOW_EOS;

  GstBuffer* b = gst_sample_get_buffer(smp);
  GstMapInfo m;
  if (b && gst_buffer_map(b, &m, GST_MAP_READ)) {
    size_t need = (size_t)s->w * s->h * 4;
    if (m.size >= need) {
      memcpy(s->buf, m.data, need);
      if (dlsdk_display_show(s->disp, DLSDK_PIXEL_FORMAT_XRGB, s->buf, s->w * 4) == DLSDK_SUCCESS) {
        dlsdk_display_wait_on_show(s->disp);
        s->frames++;
      }
    }
    gst_buffer_unmap(b, &m);
  }
  gst_sample_unref(smp);

  // 跑马灯：按【字/秒】滚动（与帧率解耦）
  if (s->marquee && s->mq_ring && s->mq_len > 0 && s->mq_cps > 0) {
    double t = now_sec();
    double due = 1.0 / s->mq_cps;
    if (t - s->mq_last >= due) {
      int steps = (int)((t - s->mq_last) / due);
      if (steps > 4) steps = 4;            // 卡顿后防跳变
      s->mq_off = (s->mq_off + steps) % s->mq_len;
      s->mq_last = t;

      gchar* win = g_malloc0((gsize)s->mq_win * 6 + 8);   // UTF-8 最多 6 字节/字
      gchar* p = win;
      for (glong i = 0; i < s->mq_win; ++i) {
        glong idx = (s->mq_off + i) % s->mq_len;
        const gchar* c = g_utf8_offset_to_pointer(s->mq_ring, idx);
        p += g_unichar_to_utf8(g_utf8_get_char(c), p);
      }
      *p = '\0';
      g_object_set(s->marquee, "text", win, NULL);
      g_free(win);
    }
  }
  return g_stop ? GST_FLOW_EOS : GST_FLOW_OK;
}

// 为一个屏建管线并启动
// marquee_text = NULL 时，每屏显示【自己的】EDID 身份信息
static int start_screen(screen_t* s, const char* marquee_text, int fps, double speed,
                        unsigned max_hz) {
  // ---- 读 EDID(必须在 power_on 之前/之后都可以，这里先读) ----
  edid_info_t ei; memset(&ei, 0, sizeof(ei));
  uint32_t elen = 0;
  if (dlsdk_display_edid(s->disp, NULL, &elen) == DLSDK_SUCCESS && elen > 0 && elen < 8192) {
    uint8_t* eb = malloc(elen);
    if (eb) {
      if (dlsdk_display_edid(s->disp, eb, &elen) == DLSDK_SUCCESS)
        parse_edid(eb, elen, &ei);
      free(eb);
    }
  }

  // 挑模式：不盲从 preferred(实测 4K@160Hz 会把链路推到永久阻塞)
  dlsdk_display_mode mode; memset(&mode, 0, sizeof(mode));
  if (pick_mode(s->disp, max_hz, &mode) != 0) {
    fprintf(stderr, "[dl_clock] 屏 %d 取不到模式\n", s->idx);
    return -1;
  }
  if (dlsdk_display_power_on_with_mode(s->disp, &mode) != DLSDK_SUCCESS) {
    fprintf(stderr, "[dl_clock] 屏 %d 点亮失败\n", s->idx);
    return -1;
  }
  s->hz = mode.refreshRateHz;
  snprintf(s->name, sizeof(s->name), "%s", ei.valid ? ei.name : "No EDID");
  snprintf(s->vendor, sizeof(s->vendor), "%s", ei.valid ? ei.vendor : "???");
  s->product = ei.product;
  s->port = port_of(dlsdk_display_id(s->disp));
  dlsdk_rect sz = dlsdk_display_size(s->disp);
  s->w = sz.width; s->h = sz.height;
  s->buf = malloc((size_t)s->w * s->h * 4);
  if (!s->buf) return -1;
  s->t0 = now_sec();

  // ---- 字号（按各屏自己的分辨率算：1080p 和 4K 不一样）----
  // ★ 必须 auto-resize=false ★
  //   overlay 的 auto-resize 默认【开启】，以 640x480 为基准自动放大字体：
  //   1920 宽 -> x3 倍。写 216pt 会渲染成 648pt 直接撑爆屏幕。
  //   关掉后 font-desc 的 pt 才是真实字号：px = pt * 96/72 = pt * 1.333
  int big   = (int)(s->h * 0.28 * 0.75);
  int mid   = (int)(s->h * 0.06 * 0.75);
  int small = (int)(s->h * 0.048 * 0.75);
  if (big < 24) big = 24;
  if (mid < 10) mid = 10;
  if (small < 10) small = 10;

  // ---- 跑马灯内容：没指定 --text 就显示【这台屏自己的】EDID 详情 ----
  gchar* own = NULL;
  if (!marquee_text) {
    own = g_strdup_printf(
        "SCREEN %d  ***  %s  ***  Vendor: %s  ***  Product: 0x%04X  ***  "
        "%ux%u @%uHz  ***  DL7400 Output Port ^%d  ***  ",
        s->idx, s->name, s->vendor, s->product, s->w, s->h, s->hz, s->port);
  }
  const char* mt = marquee_text ? marquee_text : own;

  // 跑马灯 ring：原文后补空格，滚动时首尾有间隔
  gchar* pad = g_strnfill(12, ' ');
  s->mq_ring = g_strconcat(mt, pad, NULL);
  g_free(pad);
  g_free(own);
  s->mq_len = g_utf8_strlen(s->mq_ring, -1);
  double char_px = small * 1.333 * 0.6;      // 等宽字符宽 ≈ 0.6 * 字号(px)
  // 留 6% 边距：按满屏宽算的话，字宽估算稍有偏差就会贴边被切(wrap-mode=none 不换行)
  s->mq_win = (glong)(s->w * 0.94 / char_px);
  if (s->mq_win < 8) s->mq_win = 8;
  if (s->mq_win > s->mq_len) s->mq_win = s->mq_len;
  s->mq_off = 0;
  s->mq_cps = speed;
  s->mq_last = now_sec();

  // ---- 时钟正下方那行固定的身份信息(不滚动，一眼能看清是哪台屏) ----
  // textoverlay 的文本要经过 gst_parse_launch，含特殊字符会解析失败 -> 只用安全字符
  gchar* idline = g_strdup_printf("[%d] %s  %s 0x%04X  %ux%u@%uHz  PORT^%d",
                                  s->idx, s->name, s->vendor, s->product,
                                  s->w, s->h, s->hz, s->port);

  // 身份行字号：这行比日期长得多，用 mid 会超出屏幕被切掉(wrap-mode=none 不换行)。
  // 按【屏宽 / 实际字符数】反推一个能装下的字号，再留 6% 边距。
  //   等宽字体单字宽 ≈ 0.6 * 字号(px)，px = pt * 96/72 = pt * 1.333
  //   => pt = 屏宽 / 字符数 / 0.6 / 1.333
  int idlen = (int)g_utf8_strlen(idline, -1);
  if (idlen < 1) idlen = 1;
  int idpt = (int)((double)s->w * 0.94 / idlen / 0.6 / 1.333);
  if (idpt > mid)   idpt = mid;     // 不超过日期字号
  if (idpt < 9)     idpt = 9;       // 太小就没意义了

  // 管线: 黑底 -> 大时钟 -> 日期 -> 身份信息 -> 跑马灯 -> appsink
  //  * wrap-mode=none : 否则长文本自动换行、铺满全屏盖住时钟
  //  * ypos 需配合 valignment=position 使用，把身份行放在时钟下方(0.72 屏高处)
  gchar* desc = g_strdup_printf(
      "videotestsrc pattern=black is-live=true ! "
      "video/x-raw,format=BGRA,width=%u,height=%u,framerate=%d/1 ! "
      "clockoverlay time-format=\"%%H:%%M:%%S\" font-desc=\"Liberation Sans Bold %d\" "
      "  halignment=center valignment=center auto-resize=false shaded-background=false ! "
      "clockoverlay time-format=\"%%Y-%%m-%%d  %%A\" font-desc=\"Liberation Sans %d\" "
      "  halignment=center valignment=top auto-resize=false shaded-background=false ! "
      "textoverlay text=\"%s\" font-desc=\"Liberation Mono Bold %d\" "
      "  halignment=center valignment=position ypos=0.72 auto-resize=false wrap-mode=none "
      "  shaded-background=true ! "
      "textoverlay name=mq font-desc=\"Liberation Mono Bold %d\" "
      "  halignment=center valignment=bottom auto-resize=false wrap-mode=none "
      "  shaded-background=true ! "
      "videoconvert ! video/x-raw,format=BGRA ! "
      "appsink name=out emit-signals=true max-buffers=2 drop=true sync=true",
      s->w, s->h, fps, big, mid, idline, idpt, small);
  g_free(idline);

  GError* err = NULL;
  s->pipe = gst_parse_launch(desc, &err);
  g_free(desc);
  if (!s->pipe) {
    fprintf(stderr, "[dl_clock] 屏 %d 建 pipeline 失败: %s\n", s->idx, err ? err->message : "?");
    return -1;
  }
  s->marquee = gst_bin_get_by_name(GST_BIN(s->pipe), "mq");
  GstAppSink* sink = GST_APP_SINK(gst_bin_get_by_name(GST_BIN(s->pipe), "out"));
  GstAppSinkCallbacks cbs = {0};
  cbs.new_sample = on_sample;
  gst_app_sink_set_callbacks(sink, &cbs, s, NULL);
  gst_object_unref(sink);

  gst_element_set_state(s->pipe, GST_STATE_PLAYING);
  printf("[dl_clock] 屏 %d: %ux%u @%uHz 已点亮 | %s (%s 0x%04X) | DL7400 口 ^%d\n",
         s->idx, s->w, s->h, s->hz, s->name, s->vendor, s->product, s->port);
  fflush(stdout);
  return 0;
}

static void stop_screen(screen_t* s) {
  if (s->pipe) {
    gst_element_set_state(s->pipe, GST_STATE_NULL);
    if (s->marquee) gst_object_unref(s->marquee);
    gst_object_unref(s->pipe);
    s->pipe = NULL;
  }
  if (s->disp) {
    dlsdk_display_clear(s->disp);
    dlsdk_display_power_off(s->disp);
  }
  free(s->buf); s->buf = NULL;
  g_free(s->mq_ring); s->mq_ring = NULL;
}

// 等待设备并取回所有 display（开机/热插拔用）
static int acquire(int wait_forever, dlsdk_device_handle* devs, unsigned* nd,
                   dlsdk_display_handle* ds, unsigned* ndisp) {
  int tries = 0;
  while (!g_stop) {
    *nd = 4;
    if (dlsdk_get_devices(devs, nd) == DLSDK_SUCCESS && *nd > 0) {
      *ndisp = MAX_SCREENS;
      if (dlsdk_device_get_displays(devs[0], ds, ndisp) == DLSDK_SUCCESS && *ndisp > 0)
        return 0;
    }
    if (!wait_forever) return -1;
    if (tries++ % 12 == 0)
      fprintf(stderr, "[dl_clock] 等待 DL7400 / 显示器接入... (%ds)\n", tries * 5);
    sleep(5);
  }
  return -1;
}

int main(int argc, char** argv) {
  const char* marquee_text = NULL;
  int only_screen = -1;          // -1 = 所有屏
  int fps = 15, wait_forever = 0;
  double speed = 15.0;
  unsigned max_hz = 60;          // 模式刷新率上限，见 pick_mode()

  for (int i = 1; i < argc; ++i) {
    if (!strcmp(argv[i], "--text") && i + 1 < argc) marquee_text = argv[++i];
    else if (!strcmp(argv[i], "--fps") && i + 1 < argc) fps = atoi(argv[++i]);
    else if (!strcmp(argv[i], "--speed") && i + 1 < argc) speed = atof(argv[++i]);
    else if (!strcmp(argv[i], "--screen") && i + 1 < argc) only_screen = atoi(argv[++i]);
    else if (!strcmp(argv[i], "--max-hz") && i + 1 < argc) max_hz = (unsigned)atoi(argv[++i]);
    else if (!strcmp(argv[i], "--wait")) wait_forever = 1;
  }
  if (max_hz < 24) max_hz = 24;
  if (fps < 1) fps = 1;
  if (fps > 30) fps = 30;
  if (speed <= 0) speed = 0.5;
  if (speed > 30) speed = 30;

  // ★ 默认文案必须是纯 ASCII ★
  //   镜像里只有 Liberation 字体，【没有任何中文字形】(fc-list :lang=zh 为空)。
  //   中文会被 Pango 渲染成"码点方框"(如 591A=多 5C4F=屏)，看起来就是乱码。
  //   要中文需往镜像加 CJK 字体(已在 astra-media.bbappend 加了 ttf-wqy-zenhei)。
  if (!marquee_text)
    marquee_text = "SL1680 + DL7400  ***  DisplayLink Multi-Screen Demo  ***  "
                   "USB3 SuperSpeed  ***  4x DP/HDMI Output  ***  Auto-start on boot  ***  ";

  signal(SIGINT, on_sig);
  signal(SIGTERM, on_sig);
  gst_init(&argc, &argv);

  dlsdk_config cfg; memset(&cfg, 0, sizeof(cfg));
  cfg.size = (uint32_t)sizeof(cfg);
  cfg.firmwarePath = FW_DIR;    // 让 SDK 自动保活/升级固件
  cfg.embeddedMode = 0;
  dlsdk_initialise_with_config(&cfg);

  dlsdk_device_handle devs[4]; unsigned int nd = 0;
  dlsdk_display_handle ds[MAX_SCREENS]; unsigned int ndisp = 0;

  if (acquire(wait_forever, devs, &nd, ds, &ndisp) != 0) {
    fprintf(stderr, "[dl_clock] 找不到 DisplayLink 设备/显示器。\n"
                    "  排查: lsusb 有没有 17e9；speed 是否 5000(USB3)\n"
                    "  卡死复位: echo -n 2-1.4.1 > /sys/bus/usb/drivers/usb/unbind; sleep 3\n"
                    "            echo -n 2-1.4.1 > /sys/bus/usb/drivers/usb/bind\n");
    dlsdk_teardown();
    return 2;
  }
  printf("[dl_clock] 发现 %u 个 display\n", ndisp);

  // ---- 启动各屏 ----
  screen_t scr[MAX_SCREENS]; memset(scr, 0, sizeof(scr));
  int started = 0;
  for (unsigned i = 0; i < ndisp && i < MAX_SCREENS; ++i) {
    if (only_screen >= 0 && (int)i != only_screen) continue;
    scr[i].idx = (int)i;
    scr[i].disp = ds[i];
    if (start_screen(&scr[i], marquee_text, fps, speed, max_hz) == 0) started++;
  }
  if (started == 0) {
    fprintf(stderr, "[dl_clock] 没有任何屏启动成功\n");
    dlsdk_teardown(); return 3;
  }
  printf("[dl_clock] %d 个屏运行中 (Ctrl+C 退出)\n", started);
  fflush(stdout);

  // ---- 主循环：看总线消息 + 定期报帧率 ----
  double t0 = now_sec(), last = t0;
  while (!g_stop) {
    for (unsigned i = 0; i < ndisp && i < MAX_SCREENS; ++i) {
      if (!scr[i].pipe) continue;
      GstBus* bus = gst_element_get_bus(scr[i].pipe);
      GstMessage* msg = gst_bus_timed_pop_filtered(bus, 50 * GST_MSECOND, GST_MESSAGE_ERROR);
      if (msg) {
        GError* e; gchar* dbg;
        gst_message_parse_error(msg, &e, &dbg);
        fprintf(stderr, "[dl_clock] 屏 %d GStreamer 错误: %s\n", scr[i].idx, e->message);
        g_error_free(e); g_free(dbg); gst_message_unref(msg);
        g_stop = 1;
      }
      gst_object_unref(bus);
    }
    double t = now_sec();
    if (t - last >= 60.0) {       // 每分钟报一次各屏帧率
      for (unsigned i = 0; i < ndisp && i < MAX_SCREENS; ++i) {
        if (!scr[i].pipe) continue;
        printf("[dl_clock] 屏 %d (%ux%u): %ld 帧, %.1f fps\n",
               scr[i].idx, scr[i].w, scr[i].h,
               scr[i].frames, scr[i].frames / (t - scr[i].t0));
      }
      fflush(stdout);
      last = t;
    }
  }

  printf("\n[dl_clock] 收到退出信号，清理中...\n");
  for (unsigned i = 0; i < ndisp && i < MAX_SCREENS; ++i) stop_screen(&scr[i]);
  for (unsigned i = 0; i < nd; ++i) dlsdk_free_device(devs[i]);
  dlsdk_teardown();
  printf("[dl_clock] 已干净退出\n");
  return 0;
}
