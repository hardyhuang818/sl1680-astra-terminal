// dl_multiscreen_demo.c — SL1680 + DL7400 多屏验证 / 吞吐实测
//
// 目的：回答"SL1680 到底能带几个屏、什么分辨率、多少帧"
//   1) 枚举 DisplayLink 设备与其下所有 display
//   2) 逐屏用首选分辨率点亮
//   3) 向每个屏连续推动态画面(强制 DL3+ 编码器满负荷)，实测 fps / MB/s
//
// 用法:
//   dl_multiscreen_demo [-n frames] [-w width -h height] [-s]
//     -n frames  每屏推多少帧(默认 120)
//     -w -h      强制分辨率(默认用屏的 preferred mode)
//     -s         静态画面模式(只推一次变化，模拟标牌场景 → 编码开销极低)
//
// 编译: gcc dl_multiscreen_demo.c -ldlsdk -lusb-1.0 -lm -o dl_multiscreen_demo

#include "dlsdk/dlsdk.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define MAX_DEV 8
#define MAX_DISP 8

static const char* FW_DIR = "/usr/share/displaylink/DL-firmware";

static double now_sec(void)
{
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return ts.tv_sec + ts.tv_nsec / 1e9;
}

static const char* status_str(dlsdk_status s)
{
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

// 画一帧：每个屏一个基色，叠一条随 frame 移动的亮带 + 渐变
// 动态内容 => 强制编码器真正干活（最坏情况，实测上限）
static void render(uint32_t* buf, unsigned w, unsigned h, int screen, int frame)
{
  static const uint32_t base[] = {
    0x00203040, 0x00402030, 0x00304020, 0x00403020, 0x00204030, 0x00302040
  };
  uint32_t bc = base[screen % (int)(sizeof(base) / sizeof(base[0]))];
  unsigned bar = (unsigned)((frame * 13) % (int)w);   // 移动的亮带

  for (unsigned y = 0; y < h; ++y) {
    uint32_t row = bc + ((y * 255 / (h ? h : 1)) & 0xFF);   // 竖向渐变
    uint32_t* p = buf + (size_t)y * w;
    for (unsigned x = 0; x < w; ++x) {
      // 亮带 120px 宽
      p[x] = ((x - bar) < 120u) ? 0x00FFFFFF : row;
    }
    // 顶部画屏号色块（粗略标识哪个屏是哪个）
    if (y < 60) {
      for (unsigned x = 0; x < 60u * (unsigned)(screen + 1) && x < w; ++x)
        p[x] = 0x00FF0000;
    }
  }
}

int main(int argc, char** argv)
{
  int frames = 120, forceW = 0, forceH = 0, staticMode = 0, c;
  while ((c = getopt(argc, argv, "n:w:h:s")) != -1) {
    switch (c) {
      case 'n': frames = atoi(optarg); break;
      case 'w': forceW = atoi(optarg); break;
      case 'h': forceH = atoi(optarg); break;
      case 's': staticMode = 1; break;
      default: break;
    }
  }

  printf("=== SL1680 + DisplayLink 多屏实测 ===\n");
  printf("SDK version : %s\n", dlsdk_version());
  printf("Firmware dir: %s\n", FW_DIR);
  printf("Frames/屏   : %d%s\n\n", frames, staticMode ? "  (静态模式)" : "  (动态内容, 最坏情况)");

  dlsdk_config cfg;
  memset(&cfg, 0, sizeof(cfg));
  cfg.size = (uint32_t)sizeof(cfg);
  cfg.firmwarePath = FW_DIR;   // 自动保活/升级设备固件
  cfg.embeddedMode = 0;
  dlsdk_initialise_with_config(&cfg);

  // --- 枚举设备 ---
  dlsdk_device_handle devs[MAX_DEV];
  unsigned int ndev = MAX_DEV;
  dlsdk_status st = dlsdk_get_devices(devs, &ndev);
  if (st != DLSDK_SUCCESS) {
    printf("dlsdk_get_devices 失败: %s\n", status_str(st));
    printf("排查: 1) DL7400 是否插在 USB3.0 口  2) lsusb 有没有 17e9  3) /dev/bus/usb 权限\n");
    dlsdk_teardown();
    return 1;
  }
  printf("发现 DisplayLink 设备: %u 个\n", ndev);
  if (ndev == 0) {
    printf("(没插设备，或固件不兼容)\n");
    dlsdk_teardown();
    return 0;
  }

  unsigned total_disp = 0;

  for (unsigned d = 0; d < ndev; ++d) {
    printf("\n──────────────────────────────────────────\n");
    printf("设备 #%u  id=%s\n", d, dlsdk_device_id(devs[d]));
    printf("  固件版本: %s\n", dlsdk_device_firmware_version(devs[d]));

    dlsdk_display_handle disp[MAX_DISP];
    unsigned int ndisp = MAX_DISP;
    st = dlsdk_device_get_displays(devs[d], disp, &ndisp);
    if (st != DLSDK_SUCCESS) {
      printf("  get_displays 失败: %s\n", status_str(st));
      continue;
    }
    printf("  ★ 该设备下的 display 数: %u\n", ndisp);
    total_disp += ndisp;

    for (unsigned i = 0; i < ndisp; ++i) {
      printf("\n  ── 屏 #%u  id=%s\n", i, dlsdk_display_id(disp[i]));

      dlsdk_display_mode mode;
      memset(&mode, 0, sizeof(mode));
      st = dlsdk_display_preferred_mode(disp[i], &mode);
      if (st == DLSDK_SUCCESS)
        printf("     首选模式: %ux%u @%uHz\n",
               mode.resolution.width, mode.resolution.height, mode.refreshRateHz);
      else
        printf("     preferred_mode 失败: %s (可能没接屏)\n", status_str(st));

      // 钳到 ≤60Hz：Mi Monitor 这类 EDID 首选 4K@160，USB3 链路喂不动会永久卡死。
      // 同分辨率找 ≤60Hz 的最高刷新率替代（当年就是在这支程序上踩的坑）。
      if (st == DLSDK_SUCCESS && mode.refreshRateHz > 60) {
        unsigned mc = 0;
        if (dlsdk_display_modes(disp[i], NULL, &mc) == DLSDK_SUCCESS && mc && mc <= 512) {
          dlsdk_display_mode* ms = (dlsdk_display_mode*)malloc(sizeof(*ms) * mc);
          if (ms && dlsdk_display_modes(disp[i], ms, &mc) == DLSDK_SUCCESS) {
            int best = -1;
            for (unsigned k = 0; k < mc; ++k) {
              if (ms[k].resolution.width != mode.resolution.width) continue;
              if (ms[k].resolution.height != mode.resolution.height) continue;
              if (ms[k].refreshRateHz > 60) continue;
              if (best < 0 || ms[k].refreshRateHz > ms[best].refreshRateHz) best = (int)k;
            }
            if (best >= 0) {
              mode = ms[best];
              printf("     钳制到: %ux%u @%uHz (原首选>60Hz 会卡死链路)\n",
                     mode.resolution.width, mode.resolution.height, mode.refreshRateHz);
            }
          }
          free(ms);
        }
      }

      if (forceW && forceH) {
        mode.resolution.width = (unsigned)forceW;
        mode.resolution.height = (unsigned)forceH;
        if (!mode.refreshRateHz) mode.refreshRateHz = 60;
        printf("     强制模式: %dx%d @%uHz\n", forceW, forceH, mode.refreshRateHz);
      }
      if (!mode.resolution.width || !mode.resolution.height) {
        printf("     跳过(无有效分辨率)\n");
        continue;
      }

      st = dlsdk_display_power_on_with_mode(disp[i], &mode);
      if (st != DLSDK_SUCCESS) {
        printf("     点亮失败: %s\n", status_str(st));
        continue;
      }
      dlsdk_rect sz = dlsdk_display_size(disp[i]);
      printf("     ✅ 已点亮: %ux%u\n", sz.width, sz.height);

      unsigned w = sz.width, h = sz.height;
      size_t stride = (size_t)w * 4;
      uint32_t* buf = (uint32_t*)malloc(stride * h);
      if (!buf) { printf("     内存不足\n"); continue; }

      // --- 吞吐实测 ---
      double t0 = now_sec();
      int pushed = 0;
      for (int f = 0; f < frames; ++f) {
        if (!staticMode || f == 0)
          render(buf, w, h, (int)(total_disp - ndisp + i), f);
        st = dlsdk_display_show(disp[i], DLSDK_PIXEL_FORMAT_XRGB, buf, (unsigned)stride);
        if (st != DLSDK_SUCCESS) { printf("     show 失败: %s\n", status_str(st)); break; }
        st = dlsdk_display_wait_on_show(disp[i]);
        if (st != DLSDK_SUCCESS) { printf("     wait_on_show: %s\n", status_str(st)); break; }
        pushed++;
      }
      double dt = now_sec() - t0;
      free(buf);

      if (pushed > 0 && dt > 0) {
        double fps = pushed / dt;
        double mbps = (double)stride * h * pushed / dt / (1024.0 * 1024.0);
        printf("     ★ 实测: %d 帧 / %.2fs = %.1f fps  (未压缩等效 %.0f MB/s)\n",
               pushed, dt, fps, mbps);
      }
    }
  }

  printf("\n══════════════════════════════════════════\n");
  printf("总计: %u 个 DisplayLink 设备, %u 个 display\n", ndev, total_disp);
  printf("══════════════════════════════════════════\n");

  for (unsigned d = 0; d < ndev; ++d) dlsdk_free_device(devs[d]);
  dlsdk_teardown();
  return 0;
}
