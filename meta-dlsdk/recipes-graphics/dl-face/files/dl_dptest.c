// dl_dptest —— DisplayLink DP AUX 检测能力实测工具
//
// 目的：验证 dlsdk_dpaux_detect / dlsdk_dpaux_read 能否检测"显示器断电"，
//       以及能否在显示器重新上电后强制链路训练把它点亮。
//       (SDK 的热插拔回调 dlsdk_register_hotplug_callback 在本板返回
//        DLSDK_UNSUCCESSFUL —— 它依赖 libusb hotplug，本平台不支持。)
//
// 用法: dl_dptest [轮询秒数]   不带参数=只测一次
//       需要先 systemctl stop dl-face (dlsdk 单进程独占)
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
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
static const char* aux_name(enum AuxStatus a) {
  switch (a) {
    case AuxAck: return "Ack(正常)";
    case AuxNativeNak: return "Nak";
    case AuxNativeDefer: return "Defer";
    case AuxTimeout: return "Timeout(无响应)";
    case AuxError: return "Error";
    case AuxDetached: return "Detached(屏没了!)";
    default: return "?";
  }
}

static void probe(dlsdk_display_handle d, unsigned i) {
  dlsdk_rect sz = dlsdk_display_size(d);
  printf("  屏%u  %ux%u\n", i, sz.width, sz.height);

  // ① EDID 还读得到吗(屏断电后 EDID EEPROM 可能掉电)
  uint32_t elen = 0;
  dlsdk_status es = dlsdk_display_edid(d, NULL, &elen);
  printf("      EDID:        %-16s (len=%u)\n", st_name(es), elen);

  // ② 首选模式还在吗
  dlsdk_display_mode pm; memset(&pm, 0, sizeof pm);
  dlsdk_status ms = dlsdk_display_preferred_mode(d, &pm);
  printf("      首选模式:    %-16s (%ux%u@%uHz)\n", st_name(ms),
         pm.resolution.width, pm.resolution.height, pm.refreshRateHz);

  // ③ DP AUX 通道 —— 关键
  dlsdk_dpaux_handle ax = dlsdk_display_get_dpaux(d);
  if (!ax) {
    printf("      DP AUX:      NULL (此屏不是 DisplayPort 连接, 用不了 dpaux 检测)\n");
    return;
  }
  printf("      DP AUX:      有句柄\n");

  // 读 DPCD 0x00 (DPCD_REV) —— 屏在的话应该 Ack
  uint8_t rev = 0;
  enum AuxStatus ar = dlsdk_dpaux_read(ax, 0x0000, &rev, 1);
  printf("      AUX读DPCD:   %-16s (DPCD_REV=0x%02X)\n", aux_name(ar), rev);

  // 读 0x200 (SINK_COUNT) —— 屏在=1
  uint8_t sc = 0;
  enum AuxStatus ar2 = dlsdk_dpaux_read(ax, 0x0200, &sc, 1);
  printf("      SINK_COUNT:  %-16s (值=0x%02X)\n", aux_name(ar2), sc);

  // ④ 核心: detect + force training
  dlsdk_status ds = dlsdk_dpaux_detect(ax);
  printf("      dpaux_detect:%-16s  <<< 检测+强制链路训练\n", st_name(ds));
}

int main(int argc, char** argv) {
  int loop = (argc > 1) ? atoi(argv[1]) : 0;

  dlsdk_config cfg; memset(&cfg, 0, sizeof cfg);
  cfg.size = (uint32_t)sizeof cfg;
  cfg.firmwarePath = "/usr/share/displaylink/DL-firmware";
  cfg.embeddedMode = 0;
  dlsdk_initialise_with_config(&cfg);

  dlsdk_device_handle devs[4]; unsigned nd = 4;
  if (dlsdk_get_devices(devs, &nd) != DLSDK_SUCCESS || nd == 0) {
    printf("找不到 DisplayLink 设备(dl-face 还在跑? 先 systemctl stop dl-face)\n");
    dlsdk_teardown(); return 2;
  }
  printf("设备数: %u  固件: %s\n", nd, dlsdk_device_firmware_version(devs[0]));
  printf("SDK 版本: %s\n\n", dlsdk_version());

  int round = 0;
  do {
    dlsdk_display_handle ds[MAXD]; unsigned n = MAXD;
    dlsdk_status s = dlsdk_device_get_displays(devs[0], ds, &n);
    printf("[第%d轮] get_displays: %s, 显示器数=%u\n", ++round, st_name(s), n);
    for (unsigned i = 0; i < n; ++i) probe(ds[i], i);
    printf("\n");
    fflush(stdout);
    if (loop > 0) sleep((unsigned)loop);
  } while (loop > 0);

  for (unsigned k = 0; k < nd; ++k) dlsdk_free_device(devs[k]);
  dlsdk_teardown();
  return 0;
}
