// dl_hptest —— 验证「热插拔回调注册失败」的根因
//
// 问题: dlsdk_register_hotplug_callback() 在 SL1680 上返回 DLSDK_UNSUCCESSFUL(2)。
// 假设: libdlsdk.so 的热插拔基于 libusb_hotplug_register_callback，
//       而 libusb 热插拔需要平台支持(LIBUSB_CAP_HAS_HOTPLUG)。
// 本工具把这个假设变成实测: 直接问 libusb 支不支持热插拔。
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <dlsdk/dlsdk.h>

// 直接声明 libusb 的 C API，避免依赖 libusb 头文件
#define LIBUSB_CAP_HAS_CAPABILITY      0x0000
#define LIBUSB_CAP_HAS_HOTPLUG         0x0001
#define LIBUSB_CAP_HAS_HID_ACCESS      0x0100
#define LIBUSB_CAP_SUPPORTS_DETACH_KERNEL_DRIVER 0x0101
extern int  libusb_has_capability(uint32_t capability);
extern int  libusb_init(void** ctx);
extern void libusb_exit(void* ctx);
extern const char* libusb_get_version(void);   /* 可能不存在，弱引用兜底 */

static void hp_cb(dlsdk_hotplug_event_data* d, void* u) {
  (void)u;
  printf("  !! 收到热插拔事件 event=%d\n", (int)d->event);
}

int main(void) {
  printf("════════ libusb 热插拔能力实测 ════════\n");
  void* ctx = NULL;
  int ir = libusb_init(&ctx);
  printf("  libusb_init: %d (%s)\n", ir, ir == 0 ? "OK" : "FAILED");

  int cap_capability = libusb_has_capability(LIBUSB_CAP_HAS_CAPABILITY);
  int cap_hotplug    = libusb_has_capability(LIBUSB_CAP_HAS_HOTPLUG);
  int cap_hid        = libusb_has_capability(LIBUSB_CAP_HAS_HID_ACCESS);
  int cap_detach     = libusb_has_capability(LIBUSB_CAP_SUPPORTS_DETACH_KERNEL_DRIVER);

  printf("  LIBUSB_CAP_HAS_CAPABILITY               = %d\n", cap_capability);
  printf("  LIBUSB_CAP_HAS_HOTPLUG                  = %d   <<< 关键\n", cap_hotplug);
  printf("  LIBUSB_CAP_HAS_HID_ACCESS               = %d\n", cap_hid);
  printf("  LIBUSB_CAP_SUPPORTS_DETACH_KERNEL_DRIVER= %d\n", cap_detach);
  printf("  ──> libusb 热插拔: %s\n",
         cap_hotplug ? "支持 (那么根因不在 libusb)" : "**不支持** (这就是根因)");
  if (ctx) libusb_exit(ctx);

  printf("\n════════ dlsdk 热插拔注册实测 ════════\n");
  dlsdk_config cfg; memset(&cfg, 0, sizeof cfg);
  cfg.size = (uint32_t)sizeof cfg;
  cfg.firmwarePath = "/usr/share/displaylink/DL-firmware";
  cfg.embeddedMode = 0;
  dlsdk_initialise_with_config(&cfg);
  printf("  SDK 版本: %s\n", dlsdk_version());

  // ① 初始化后立刻注册
  dlsdk_hotplug_callback_handle h1 = NULL;
  dlsdk_status s1 = dlsdk_register_hotplug_callback(hp_cb, NULL, &h1);
  printf("  注册(枚举前): status=%d handle=%s\n", (int)s1, h1 ? "有效" : "NULL");

  // ② 枚举设备后再注册一次
  dlsdk_device_handle devs[4]; unsigned nd = 4;
  dlsdk_status gs = dlsdk_get_devices(devs, &nd);
  printf("  get_devices: status=%d 设备数=%u\n", (int)gs, nd);
  if (gs == DLSDK_SUCCESS && nd > 0)
    printf("  固件版本: %s\n", dlsdk_device_firmware_version(devs[0]));

  dlsdk_hotplug_callback_handle h2 = NULL;
  dlsdk_status s2 = dlsdk_register_hotplug_callback(hp_cb, NULL, &h2);
  printf("  注册(枚举后): status=%d handle=%s\n", (int)s2, h2 ? "有效" : "NULL");

  printf("\n  status 含义: 0=SUCCESS 2=UNSUCCESSFUL 9=NOT_IMPLEMENTED\n");

  for (unsigned k = 0; k < nd; ++k) dlsdk_free_device(devs[k]);
  dlsdk_teardown();
  return 0;
}
