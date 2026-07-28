// dl_player.c — 把真实内容送到 DisplayLink 屏上（SL1680 + DL7400）
//
// 这是"视频源从哪来"的答案：用 GStreamer 解码(硬解) -> appsink 取帧 -> dlsdk_display_show()
//
// 用法:
//   dl_player <文件或URI>            播放视频(H.264/H.265/VP9/AV1 硬解)
//   dl_player <图片.png/.jpg>        显示图片并保持
//   dl_player --test                 显示测试图并保持(不需要素材)
//   dl_player --hold <秒>            显示多久(默认一直显示到 Ctrl+C)
//   dl_player --screen <n>           送到第 n 个屏(默认 0)
//
// 关键点:
//   * 程序【持续运行】画面才一直在；退出=释放显示=屏幕变黑(这是 DLSDK 的设计)
//   * Ctrl+C 会干净 teardown，避免设备卡死(卡死只能 usb unbind/bind 复位)
//
// 编译: gcc dl_player.c $(pkg-config --cflags --libs gstreamer-1.0 gstreamer-app-1.0) -ldlsdk -lusb-1.0 -lm -o dl_player

#include "dlsdk/dlsdk.h"
#include <gst/gst.h>
#include <gst/app/gstappsink.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <unistd.h>
#include <time.h>

static volatile sig_atomic_t g_stop = 0;
static void on_sigint(int s) { (void)s; g_stop = 1; }

static const char* FW_DIR = "/usr/share/displaylink/DL-firmware";

typedef struct {
  dlsdk_display_handle disp;
  unsigned w, h;
  uint32_t* buf;      // XRGB 目标缓冲
  long frames;
  double t0;
} target_t;

static double now_sec(void) {
  struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
  return ts.tv_sec + ts.tv_nsec / 1e9;
}

// ---- 推一帧到 DisplayLink ----
static void push(target_t* t) {
  if (dlsdk_display_show(t->disp, DLSDK_PIXEL_FORMAT_XRGB, t->buf, t->w * 4) == DLSDK_SUCCESS) {
    dlsdk_display_wait_on_show(t->disp);
    t->frames++;
  }
}

// ---- GStreamer: 每解出一帧就推给 DL ----
static GstFlowReturn on_new_sample(GstAppSink* sink, gpointer user) {
  target_t* t = (target_t*)user;
  GstSample* smp = gst_app_sink_pull_sample(sink);
  if (!smp) return GST_FLOW_EOS;

  GstBuffer* b = gst_sample_get_buffer(smp);
  GstMapInfo m;
  if (b && gst_buffer_map(b, &m, GST_MAP_READ)) {
    // caps 已强制为 BGRA(硬件缩放) 或 BGRx(软件兜底)，
    // 两者 32bpp 内存布局都与 DLSDK_PIXEL_FORMAT_XRGB 一致(小端 B,G,R,X/A)
    size_t need = (size_t)t->w * t->h * 4;
    if (m.size >= need) {
      memcpy(t->buf, m.data, need);
      push(t);
    }
    gst_buffer_unmap(b, &m);
  }
  gst_sample_unref(smp);
  return g_stop ? GST_FLOW_EOS : GST_FLOW_OK;
}

// ---- 测试图(无素材时用) ----
static void render_test(uint32_t* buf, unsigned w, unsigned h, int frame) {
  unsigned bar = (unsigned)((frame * 9) % (int)w);
  for (unsigned y = 0; y < h; ++y) {
    uint32_t row = 0x00203040 + ((y * 255 / (h ? h : 1)) & 0xFF);
    uint32_t* p = buf + (size_t)y * w;
    for (unsigned x = 0; x < w; ++x)
      p[x] = ((x - bar) < 140u) ? 0x00FFFFFF : row;
    if (y < 80) for (unsigned x = 0; x < 200u && x < w; ++x) p[x] = 0x00FF3030;
  }
}

int main(int argc, char** argv) {
  const char* src = NULL;
  int screen = 0; double hold = -1; int testmode = 0;
  int cameramode = 0;
  const char* cam_dev = "/dev/v4l/by-id/usb-046d_HD_Pro_Webcam_C920-video-index0";

  for (int i = 1; i < argc; ++i) {
    if (!strcmp(argv[i], "--test")) testmode = 1;
    else if (!strcmp(argv[i], "--camera")) {
      cameramode = 1;
      if (i + 1 < argc && argv[i + 1][0] == '/') cam_dev = argv[++i];
    }
    else if (!strcmp(argv[i], "--hold") && i + 1 < argc) hold = atof(argv[++i]);
    else if (!strcmp(argv[i], "--screen") && i + 1 < argc) screen = atoi(argv[++i]);
    else src = argv[i];
  }
  if (!src && !testmode && !cameramode) {
    fprintf(stderr,
      "用法:\n"
      "  dl_player <视频文件|图片|URI>   播放/显示(硬解)\n"
      "  dl_player --test               显示测试图\n"
      "  dl_player --camera [/dev/videoN] 摄像头实时画面(默认 C920)\n"
      "                                 ⚠ 先 systemctl stop vision-wake(它独占摄像头)\n"
      "  可选: --hold <秒>  --screen <n>\n");
    return 1;
  }

  signal(SIGINT, on_sigint);
  signal(SIGTERM, on_sigint);
  gst_init(&argc, &argv);

  // ---- 1) 初始化 SDK（firmwarePath 让 SDK 自动保活/升级固件）----
  dlsdk_config cfg; memset(&cfg, 0, sizeof(cfg));
  cfg.size = (uint32_t)sizeof(cfg);
  cfg.firmwarePath = FW_DIR;
  cfg.embeddedMode = 0;
  dlsdk_initialise_with_config(&cfg);

  dlsdk_device_handle devs[4]; unsigned int nd = 4;
  if (dlsdk_get_devices(devs, &nd) != DLSDK_SUCCESS || nd == 0) {
    fprintf(stderr, "找不到 DisplayLink 设备。\n"
                    "排查: 1) lsusb 有没有 17e9  2) speed 是不是 5000(USB3)\n"
                    "     3) 设备是否卡死 -> 复位:\n"
                    "        echo -n 2-1.4.1 > /sys/bus/usb/drivers/usb/unbind; sleep 3\n"
                    "        echo -n 2-1.4.1 > /sys/bus/usb/drivers/usb/bind\n");
    dlsdk_teardown(); return 2;
  }

  dlsdk_display_handle disps[8]; unsigned int ndisp = 8;
  if (dlsdk_device_get_displays(devs[0], disps, &ndisp) != DLSDK_SUCCESS || ndisp == 0) {
    fprintf(stderr, "设备下没有可用的屏(HDMI 没接?)\n"); dlsdk_teardown(); return 3;
  }
  if (screen >= (int)ndisp) { fprintf(stderr, "只有 %u 个屏\n", ndisp); dlsdk_teardown(); return 4; }

  target_t t; memset(&t, 0, sizeof(t));
  t.disp = disps[screen];

  dlsdk_display_mode mode; memset(&mode, 0, sizeof(mode));
  dlsdk_display_preferred_mode(t.disp, &mode);
  // 钳到 ≤60Hz：Mi Monitor 等 EDID 首选 4K@160，USB3 喂不动会永久卡死链路
  if (mode.refreshRateHz > 60) {
    unsigned mc = 0;
    if (dlsdk_display_modes(t.disp, NULL, &mc) == DLSDK_SUCCESS && mc && mc <= 512) {
      dlsdk_display_mode* ms = malloc(sizeof(*ms) * mc);
      if (ms && dlsdk_display_modes(t.disp, ms, &mc) == DLSDK_SUCCESS) {
        int best = -1;
        for (unsigned k = 0; k < mc; ++k) {
          if (ms[k].resolution.width != mode.resolution.width) continue;
          if (ms[k].resolution.height != mode.resolution.height) continue;
          if (ms[k].refreshRateHz > 60) continue;
          if (best < 0 || ms[k].refreshRateHz > ms[best].refreshRateHz) best = (int)k;
        }
        if (best >= 0) { mode = ms[best]; printf("首选>60Hz，钳制到 @%uHz\n", mode.refreshRateHz); }
      }
      free(ms);
    }
  }
  if (dlsdk_display_power_on_with_mode(t.disp, &mode) != DLSDK_SUCCESS) {
    fprintf(stderr, "点亮失败\n"); dlsdk_teardown(); return 5;
  }
  dlsdk_rect sz = dlsdk_display_size(t.disp);
  t.w = sz.width; t.h = sz.height;
  t.buf = malloc((size_t)t.w * t.h * 4);
  if (!t.buf) { dlsdk_teardown(); return 6; }

  printf("屏 %d: %ux%u @%uHz  已点亮\n", screen, t.w, t.h, mode.refreshRateHz);
  printf("按 Ctrl+C 退出(会干净释放设备)\n");
  fflush(stdout);

  t.t0 = now_sec();

  if (testmode) {
    // ---- 测试图：持续刷新直到 Ctrl+C / hold 到期 ----
    printf("模式: 测试图\n"); fflush(stdout);
    for (int f = 0; !g_stop; ++f) {
      render_test(t.buf, t.w, t.h, f);
      push(&t);
      if (hold > 0 && now_sec() - t.t0 >= hold) break;
    }
  } else {
    // ---- GStreamer：解码(硬解) -> 缩放到屏分辨率 -> appsink -> 推 ----
    // uridecodebin 自动选 v4l2vp9dec / v4l2h264dec / v4l2h265dec 等硬解插件。
    //
    // ★ 缩放必须走硬件 ★ 实测(4K VP9 -> 1080p，150帧):
    //     纯硬解                        1.35s = 111 fps
    //     + 软件 videoconvert/videoscale 17.55s =  8.5 fps  <- CPU 吃掉 94% 时间!
    //     + 硬件 synavideoconvertscale   5.63s = 26.6 fps  <- 快 3 倍
    // synavideoconvertscale 只输出 RGB/BGRA/NV12/I420/YUY2（没有 BGRx），
    // 用 BGRA：32bpp 内存布局与 DLSDK_PIXEL_FORMAT_XRGB 一致(小端 B,G,R,A)。
    gchar* uri = NULL;
    gchar* desc;
    if (cameramode) {
      // C920 出 MJPEG，jpegdec 后走硬件缩放到屏分辨率。
      // sync=false：相机是实况源，不按时间戳等，来一帧推一帧
      desc = g_strdup_printf(
          "v4l2src device=%s ! image/jpeg,width=1280,height=720,framerate=30/1 ! "
          "jpegdec ! synavideoconvertscale ! "
          "video/x-raw,format=BGRA,width=%u,height=%u ! "
          "appsink name=out emit-signals=true max-buffers=2 drop=true sync=false",
          cam_dev, t.w, t.h);
    } else {
      uri = gst_uri_is_valid(src) ? g_strdup(src) : gst_filename_to_uri(src, NULL);
      desc = g_strdup_printf(
          "uridecodebin uri=\"%s\" ! synavideoconvertscale ! "
          "video/x-raw,format=BGRA,width=%u,height=%u ! "
          "appsink name=out emit-signals=true max-buffers=2 drop=true sync=true",
          uri, t.w, t.h);
    }
    GError* err = NULL;
    GstElement* pipe = gst_parse_launch(desc, &err);
    if (!pipe) {
      // 兜底：没有硬件缩放插件时退回软件路径(慢，但能出图)
      fprintf(stderr, "硬件缩放不可用(%s)，退回软件缩放\n", err ? err->message : "?");
      if (err) { g_error_free(err); err = NULL; }
      g_free(desc);
      if (cameramode)
        desc = g_strdup_printf(
            "v4l2src device=%s ! image/jpeg,width=1280,height=720,framerate=30/1 ! "
            "jpegdec ! videoconvert ! videoscale ! "
            "video/x-raw,format=BGRx,width=%u,height=%u ! "
            "appsink name=out emit-signals=true max-buffers=2 drop=true sync=false",
            cam_dev, t.w, t.h);
      else
        desc = g_strdup_printf(
            "uridecodebin uri=\"%s\" ! videoconvert ! videoscale ! "
            "video/x-raw,format=BGRx,width=%u,height=%u ! "
            "appsink name=out emit-signals=true max-buffers=2 drop=true sync=true",
            uri, t.w, t.h);
      pipe = gst_parse_launch(desc, &err);
    }
    g_free(desc); if (uri) g_free(uri);
    if (!pipe) {
      fprintf(stderr, "建 pipeline 失败: %s\n", err ? err->message : "?");
      free(t.buf); dlsdk_teardown(); return 7;
    }
    GstAppSink* sink = GST_APP_SINK(gst_bin_get_by_name(GST_BIN(pipe), "out"));
    GstAppSinkCallbacks cbs = {0};
    cbs.new_sample = on_new_sample;
    gst_app_sink_set_callbacks(sink, &cbs, &t, NULL);

    gst_element_set_state(pipe, GST_STATE_PLAYING);
    printf("模式: %s%s\n", cameramode ? "摄像头 " : "播放 ",
           cameramode ? cam_dev : src);
    fflush(stdout);

    GstBus* bus = gst_element_get_bus(pipe);
    int got_eos = 0;
    while (!g_stop) {
      GstMessage* msg = gst_bus_timed_pop_filtered(bus, 200 * GST_MSECOND,
                          GST_MESSAGE_ERROR | GST_MESSAGE_EOS);
      if (msg) {
        if (GST_MESSAGE_TYPE(msg) == GST_MESSAGE_ERROR) {
          GError* e; gchar* dbg;
          gst_message_parse_error(msg, &e, &dbg);
          fprintf(stderr, "GStreamer 错误: %s\n", e->message);
          g_error_free(e); g_free(dbg); gst_message_unref(msg); break;
        }
        gst_message_unref(msg);
        got_eos = 1;
        break;  // 播完/图片只有一帧
      }
      if (hold > 0 && now_sec() - t.t0 >= hold) break;
    }
    gst_object_unref(bus);
    gst_element_set_state(pipe, GST_STATE_NULL);
    gst_object_unref(sink); gst_object_unref(pipe);

    // ★ 关键：EOS 后【保持最后一帧】，而不是退出让屏幕变黑。
    //   图片只有 1 帧、视频播完，都走这里。
    //   DLSDK 需要持续 show 才能保持画面，所以低频重推同一帧。
    if (got_eos && !g_stop && t.frames > 0) {
      printf("内容已送完，保持画面中%s (Ctrl+C 退出)\n",
             hold > 0 ? "" : " — 一直保持");
      fflush(stdout);
      while (!g_stop) {
        push(&t);
        if (hold > 0 && now_sec() - t.t0 >= hold) break;
        usleep(100000);   // 10Hz 重推，足够保持且几乎不吃 CPU
      }
    }
  }

  double dt = now_sec() - t.t0;
  printf("\n共推 %ld 帧 / %.1fs = %.1f fps\n", t.frames, dt, dt > 0 ? t.frames / dt : 0);

  // ---- 干净收尾：必须 teardown，否则设备卡死 ----
  dlsdk_display_clear(t.disp);
  dlsdk_display_power_off(t.disp);
  free(t.buf);
  for (unsigned i = 0; i < nd; ++i) dlsdk_free_device(devs[i]);
  dlsdk_teardown();
  printf("已干净退出\n");
  return 0;
}
