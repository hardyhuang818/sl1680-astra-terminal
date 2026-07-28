// dl_frametest —— 验证「推帧路径本身」能否区分显示器在/不在
//
// 背景: 三条检测路都不行 ——
//   ① dlsdk_register_hotplug_callback 注册就失败(status=2)
//   ② EDID/preferred_mode/get_displays 都是缓存，屏断电照样 SUCCESS
//   ③ 对断开的 sink 调 dpaux_read，并发推帧时会让整个 device 所有输出黑屏(实测踩过)
//
// 本工具测第四条路: dlsdk_display_show / dlsdk_display_wait_on_show_for 的返回值。
// 这两个调用**本来就在推帧路径里**，不引入任何额外的 SDK 调用和锁竞争 ——
// 如果它们能区分，就是最安全的检测点(原代码把 wait_on_show 的返回值丢了)。
//
// 用法: dl_frametest [轮数]    先 systemctl stop dl-face
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdint.h>
#include <dlsdk/dlsdk.h>

#define MAXD 8

static const char* st_name(dlsdk_status s) {
  switch (s) {
    case DLSDK_SUCCESS: return "SUCCESS";
    case DLSDK_NOT_ENOUGH_SPACE: return "NOT_ENOUGH_SPACE";
    case DLSDK_UNSUCCESSFUL: return "UNSUCCESSFUL";
    case DLSDK_UNSUCCESSFUL_NO_DEVICE: return "NO_DEVICE";
    case DLSDK_UNSUCCESSFUL_NO_MONITOR: return "NO_MONITOR";
    case DLSDK_UNSUCCESSFUL_MONITOR_OFF: return "MONITOR_OFF";
    case DLSDK_INVALID_HANDLE: return "INVALID_HANDLE";
    case DLSDK_INVALID_ARGS: return "INVALID_ARGS";
    case DLSDK_TIMEOUT: return "TIMEOUT";
    case DLSDK_NOT_IMPLEMENTED: return "NOT_IMPLEMENTED";
    default: return "?";
  }
}

// 选一个 <=60Hz 的模式（照抄 dl_face 的策略，避免 4K@160 把链路推死）
static int pick(dlsdk_display_handle d, dlsdk_display_mode* out) {
  dlsdk_display_mode pref; memset(&pref, 0, sizeof pref);
  if (dlsdk_display_preferred_mode(d, &pref) != DLSDK_SUCCESS) return -1;
  *out = pref;
  if (pref.refreshRateHz <= 60) return 0;
  unsigned mc = 0;
  if (dlsdk_display_modes(d, NULL, &mc) != DLSDK_SUCCESS || !mc || mc > 512) return 0;
  dlsdk_display_mode* ms = malloc(sizeof(dlsdk_display_mode) * mc);
  if (!ms) return 0;
  if (dlsdk_display_modes(d, ms, &mc) == DLSDK_SUCCESS)
    for (unsigned k = 0; k < mc; ++k)
      if (ms[k].refreshRateHz <= 60 &&
          ms[k].resolution.width == pref.resolution.width) { *out = ms[k]; break; }
  free(ms);
  return 0;
}

int main(int argc, char** argv) {
  int rounds = (argc > 1) ? atoi(argv[1]) : 12;

  dlsdk_config cfg; memset(&cfg, 0, sizeof cfg);
  cfg.size = (uint32_t)sizeof cfg;
  cfg.firmwarePath = "/usr/share/displaylink/DL-firmware";
  cfg.embeddedMode = 0;
  dlsdk_initialise_with_config(&cfg);

  dlsdk_device_handle devs[4]; unsigned nd = 4;
  if (dlsdk_get_devices(devs, &nd) != DLSDK_SUCCESS || nd == 0) {
    printf("没有设备(先 systemctl stop dl-face)\n"); dlsdk_teardown(); return 2;
  }
  dlsdk_display_handle ds[MAXD]; unsigned n = MAXD;
  if (dlsdk_device_get_displays(devs[0], ds, &n) != DLSDK_SUCCESS || n == 0) {
    printf("没有显示器\n"); dlsdk_teardown(); return 3;
  }
  printf("显示器数=%u  固件=%s  SDK=%s\n\n", n,
         dlsdk_device_firmware_version(devs[0]), dlsdk_version());

  uint32_t* buf[MAXD]; unsigned W[MAXD], H[MAXD]; int live[MAXD];
  for (unsigned i = 0; i < n; ++i) {
    dlsdk_display_mode m; memset(&m, 0, sizeof m);
    live[i] = 0; buf[i] = NULL;
    if (pick(ds[i], &m) != 0) { printf("屏%u 选模式失败\n", i); continue; }
    dlsdk_status ps = dlsdk_display_power_on_with_mode(ds[i], &m);
    dlsdk_rect sz = dlsdk_display_size(ds[i]);
    W[i] = sz.width ? sz.width : m.resolution.width;
    H[i] = sz.height ? sz.height : m.resolution.height;
    printf("屏%u  power_on_with_mode=%-12s  %ux%u@%uHz\n",
           i, st_name(ps), W[i], H[i], m.refreshRateHz);
    if (!W[i] || !H[i]) continue;
    buf[i] = malloc((size_t)W[i] * H[i] * 4);
    if (buf[i]) live[i] = 1;
  }
  printf("\n开始推帧，观察 show / wait_on_show 的返回值：\n");
  printf("%-6s %-22s %-22s\n", "轮", "display_show", "wait_on_show_for(1s)");

  for (int r = 0; r < rounds; ++r) {
    for (unsigned i = 0; i < n; ++i) {
      if (!live[i]) continue;
      // 交替红/蓝，确保每帧内容不同(避免 SDK 因内容相同而跳过)
      uint32_t c = (r & 1) ? 0x00FF0000u : 0x000000FFu;
      size_t px = (size_t)W[i] * H[i];
      for (size_t k = 0; k < px; ++k) buf[i][k] = c;

      dlsdk_status ss = dlsdk_display_show(ds[i], DLSDK_PIXEL_FORMAT_XRGB, buf[i], W[i] * 4);
      dlsdk_status ws = dlsdk_display_wait_on_show_for(ds[i], 1000);
      printf("屏%u r%-3d %-22s %-22s\n", i, r, st_name(ss), st_name(ws));
      fflush(stdout);
    }
    usleep(200000);
  }

  printf("\n判读: 若掉线屏的 show 或 wait_on_show 明显不同于正常屏,\n");
  printf("      就可以在【已有推帧路径】上做检测 —— 不需要任何额外 SDK 调用。\n");

  for (unsigned i = 0; i < n; ++i) if (buf[i]) free(buf[i]);
  for (unsigned k = 0; k < nd; ++k) dlsdk_free_device(devs[k]);
  dlsdk_teardown();
  return 0;
}
