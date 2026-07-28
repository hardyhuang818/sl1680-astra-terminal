// dl_trymode.c — 在指定屏上逐个尝试模式，找出真正能出画面的那个
//
// 用途：显示器"无信号"但 EDID 能读到时，用它定位是不是【带宽/模式】问题。
//   典型场景：4K@60 需要 HDMI 2.0 (18Gbps)。若线只是 HDMI 1.4 "High Speed"(10.2Gbps)，
//   EDID 照样能读(走独立低速 DDC 通道)，但 4K@60 信号发不出去 -> 屏幕判"无信号"。
//   降到 4K@30 (~8.9Gbps) 或 1080p 若能亮 => 坐实是线/带宽问题。
//
// 用法:
//   dl_trymode <屏号>              列出该屏所有模式
//   dl_trymode <屏号> <模式号> [秒] 点亮该模式并保持(默认 12 秒)，肉眼确认有没有画面
//
// 编译: gcc dl_trymode.c -ldlsdk -lusb-1.0 -o dl_trymode

#include "dlsdk/dlsdk.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>

static const char* FW_DIR = "/usr/share/displaylink/DL-firmware";
static volatile sig_atomic_t stop_ = 0;
static void on_sig(int s){ (void)s; stop_ = 1; }

static const char* st(dlsdk_status s) {
  switch (s) {
    case DLSDK_SUCCESS: return "SUCCESS";
    case DLSDK_UNSUCCESSFUL: return "UNSUCCESSFUL";
    case DLSDK_UNSUCCESSFUL_NO_MONITOR: return "NO_MONITOR";
    case DLSDK_UNSUCCESSFUL_MONITOR_OFF: return "MONITOR_OFF";
    case DLSDK_INVALID_ARGS: return "INVALID_ARGS";
    case DLSDK_TIMEOUT: return "TIMEOUT";
    default: return "其他错误";
  }
}

int main(int argc, char** argv) {
  if (argc < 2) { printf("用法: dl_trymode <屏号> [模式号] [秒]\n"); return 1; }
  int scr = atoi(argv[1]);
  int mi  = (argc > 2) ? atoi(argv[2]) : -1;
  int secs = (argc > 3) ? atoi(argv[3]) : 12;

  signal(SIGINT, on_sig);

  dlsdk_config cfg; memset(&cfg, 0, sizeof(cfg));
  cfg.size = (uint32_t)sizeof(cfg); cfg.firmwarePath = FW_DIR;
  dlsdk_initialise_with_config(&cfg);

  dlsdk_device_handle devs[4]; unsigned int nd = 4;
  if (dlsdk_get_devices(devs, &nd) != DLSDK_SUCCESS || nd == 0) { printf("无设备\n"); dlsdk_teardown(); return 2; }
  dlsdk_display_handle ds[8]; unsigned int n = 8;
  if (dlsdk_device_get_displays(devs[0], ds, &n) != DLSDK_SUCCESS || (unsigned)scr >= n) {
    printf("屏号无效(共 %u 个)\n", n); dlsdk_teardown(); return 3;
  }
  dlsdk_display_handle d = ds[scr];
  printf("屏 %d: %s\n", scr, dlsdk_display_id(d));

  unsigned int mc = 0;
  dlsdk_display_modes(d, NULL, &mc);
  dlsdk_display_mode* ms = malloc(sizeof(dlsdk_display_mode) * mc);
  dlsdk_display_modes(d, ms, &mc);

  if (mi < 0) {
    for (unsigned k = 0; k < mc; ++k)
      printf("  [%2u] %ux%u @%uHz\n", k, ms[k].resolution.width, ms[k].resolution.height, ms[k].refreshRateHz);
    free(ms); dlsdk_teardown(); return 0;
  }
  if ((unsigned)mi >= mc) { printf("模式号无效(共 %u)\n", mc); free(ms); dlsdk_teardown(); return 4; }

  dlsdk_display_mode m = ms[mi];
  printf("尝试: %ux%u @%uHz  (保持 %d 秒)\n", m.resolution.width, m.resolution.height, m.refreshRateHz, secs);

  dlsdk_status s = dlsdk_display_power_on_with_mode(d, &m);
  printf("power_on: %s\n", st(s));
  if (s != DLSDK_SUCCESS) { free(ms); dlsdk_teardown(); return 5; }

  dlsdk_rect sz = dlsdk_display_size(d);
  printf("实际生效: %ux%u\n", sz.width, sz.height);

  // 推一个高对比度测试图，肉眼一眼能看出有没有画面
  size_t stride = (size_t)sz.width * 4;
  uint32_t* buf = malloc(stride * sz.height);
  if (!buf) { free(ms); dlsdk_teardown(); return 6; }

  long frames = 0;
  for (int t = 0; t < secs * 5 && !stop_; ++t) {
    for (unsigned y = 0; y < sz.height; ++y) {
      uint32_t* p = buf + (size_t)y * sz.width;
      for (unsigned x = 0; x < sz.width; ++x) {
        // 大棋盘格 + 随时间变的色带：有画面的话非常明显
        int cb = ((x / 160) + (y / 160)) & 1;
        p[x] = cb ? 0x00FFFFFF : (0x00202020 + ((t * 6 + y / 4) & 0xFF));
      }
    }
    if (dlsdk_display_show(d, DLSDK_PIXEL_FORMAT_XRGB, buf, (unsigned)stride) == DLSDK_SUCCESS) {
      dlsdk_display_wait_on_show(d);
      frames++;
    }
    usleep(200000);
  }
  printf("共推 %ld 帧。屏上【有没有】黑白棋盘格?\n", frames);

  dlsdk_display_clear(d);
  free(buf); free(ms);
  dlsdk_free_device(devs[0]);
  dlsdk_teardown();
  return 0;
}
