// dl_edid.c — 读每个 DisplayLink 输出口的 EDID + 全部支持模式
//
// 用途：屏幕"无信号"时判断是链路问题还是模式问题。
//   * 能读到 EDID  -> DL7400 <-> 显示器的 DDC/AUX 通道是通的(线没问题)
//   * 模式列表     -> 看显示器到底支持哪些分辨率，好换一个试
//
// 编译: gcc dl_edid.c -ldlsdk -lusb-1.0 -o dl_edid

#include "dlsdk/dlsdk.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char* FW_DIR = "/usr/share/displaylink/DL-firmware";

static const char* st(dlsdk_status s) {
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

int main(void) {
  dlsdk_config cfg; memset(&cfg, 0, sizeof(cfg));
  cfg.size = (uint32_t)sizeof(cfg);
  cfg.firmwarePath = FW_DIR;
  dlsdk_initialise_with_config(&cfg);

  dlsdk_device_handle devs[4]; unsigned int nd = 4;
  if (dlsdk_get_devices(devs, &nd) != DLSDK_SUCCESS || nd == 0) {
    printf("找不到设备\n"); dlsdk_teardown(); return 1;
  }

  for (unsigned d = 0; d < nd; ++d) {
    printf("设备: %s  固件 %s\n", dlsdk_device_id(devs[d]), dlsdk_device_firmware_version(devs[d]));
    dlsdk_display_handle ds[8]; unsigned int n = 8;
    if (dlsdk_device_get_displays(devs[d], ds, &n) != DLSDK_SUCCESS) continue;
    printf("display 数: %u\n", n);

    for (unsigned i = 0; i < n; ++i) {
      printf("\n════════ 屏 %u: %s ════════\n", i, dlsdk_display_id(ds[i]));

      // ---- EDID：能读到就说明 DDC/AUX 通道是通的 ----
      uint32_t len = 0;
      dlsdk_status s = dlsdk_display_edid(ds[i], NULL, &len);
      printf("EDID 长度查询: %s, len=%u\n", st(s), len);
      if (len > 0 && len < 8192) {
        uint8_t* e = malloc(len);
        s = dlsdk_display_edid(ds[i], e, &len);
        printf("EDID 读取: %s\n", st(s));
        if (s == DLSDK_SUCCESS && len >= 128) {
          // EDID 头必须是 00 FF FF FF FF FF FF 00
          int hdr_ok = (e[0]==0x00 && e[1]==0xFF && e[2]==0xFF && e[3]==0xFF &&
                        e[4]==0xFF && e[5]==0xFF && e[6]==0xFF && e[7]==0x00);
          printf("  EDID 头: %s\n", hdr_ok ? "✅ 合法(显示器真的在)" : "❌ 非法(读到垃圾)");
          // 厂商 ID (3 字母，压缩在 2 字节里)
          unsigned m = (e[8] << 8) | e[9];
          printf("  厂商: %c%c%c  产品码: 0x%04X\n",
                 (char)(((m >> 10) & 0x1F) + 'A' - 1),
                 (char)(((m >> 5)  & 0x1F) + 'A' - 1),
                 (char)(( m        & 0x1F) + 'A' - 1),
                 (unsigned)(e[10] | (e[11] << 8)));
          printf("  EDID 版本: %u.%u   扩展块: %u\n", e[18], e[19], e[126]);
          // 显示器名称在 descriptor 里 (FC tag)
          for (int b = 54; b <= 108; b += 18) {
            if (e[b]==0 && e[b+1]==0 && e[b+2]==0 && e[b+3]==0xFC) {
              printf("  显示器名: ");
              for (int k = 5; k < 18; ++k) {
                char c = (char)e[b+k];
                if (c == 0x0A) break;
                putchar(c);
              }
              printf("\n");
            }
          }
          printf("  前16字节: ");
          for (int k = 0; k < 16; ++k) printf("%02X ", e[k]);
          printf("\n");
        }
        free(e);
      }

      // ---- 首选模式 ----
      dlsdk_display_mode pm; memset(&pm, 0, sizeof(pm));
      s = dlsdk_display_preferred_mode(ds[i], &pm);
      printf("首选模式: %s -> %ux%u @%uHz\n", st(s), pm.resolution.width, pm.resolution.height, pm.refreshRateHz);

      // ---- 全部支持的模式：无信号时可以换一个试 ----
      unsigned int mc = 0;
      s = dlsdk_display_modes(ds[i], NULL, &mc);
      printf("支持的模式数: %s, count=%u\n", st(s), mc);
      if (mc > 0 && mc < 512) {
        dlsdk_display_mode* ms = malloc(sizeof(dlsdk_display_mode) * mc);
        s = dlsdk_display_modes(ds[i], ms, &mc);
        if (s == DLSDK_SUCCESS) {
          for (unsigned k = 0; k < mc; ++k)
            printf("   [%2u] %ux%u @%uHz\n", k, ms[k].resolution.width, ms[k].resolution.height, ms[k].refreshRateHz);
        }
        free(ms);
      }
    }
    dlsdk_free_device(devs[d]);
  }
  dlsdk_teardown();
  return 0;
}
