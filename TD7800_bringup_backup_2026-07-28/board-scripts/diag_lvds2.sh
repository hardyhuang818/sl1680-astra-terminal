#!/bin/sh
echo "=== A. configfs 运行时 overlay 支持 ==="
mount -t configfs configfs /sys/kernel/config 2>/dev/null
ls /sys/kernel/config/ 2>/dev/null
ls -d /sys/kernel/config/device-tree/overlays 2>/dev/null && echo "OK: 支持运行时overlay" || echo "NO: 无 device-tree configfs"
echo
echo "=== B. U-Boot 环境变量 (找 overlay/dtbo/fdt 机制) ==="
fw_printenv 2>&1 | grep -i -E "dtbo|overlay|fdt|bootcmd|dolphin"
echo "--- 全部变量数:"
fw_printenv 2>/dev/null | wc -l
echo
echo "=== C. i2c-0 强制读扫描 (0x2c=touch, 0x0f=TC358775) ==="
i2cdetect -y -r 0 2>&1
echo
echo "=== D. drm 驱动形态 (模块可重绑?) ==="
grep -i -E "drm|syna" /proc/modules
echo "--- platform drivers:"
ls /sys/bus/platform/drivers/ | grep -i -E "drm|disp|dsi|panel"
echo "--- drm 设备:"
ls -d /sys/bus/platform/drivers/*drm*/f* 2>/dev/null
echo
echo "=== E. 两个 dtbo 的目标校验 (fdtdump有没有) ==="
which fdtdump dtc 2>/dev/null || echo "(板上无dtc/fdtdump)"
md5sum /boot/dolphin-td7800-lvds-overlay.dtbo /boot/dolphin-tcm2-touch-overlay.dtbo
