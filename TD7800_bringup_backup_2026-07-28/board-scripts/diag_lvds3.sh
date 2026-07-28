#!/bin/sh
echo "=== debugfs 挂载状态 ==="
mount | grep -c debugfs
ls /sys/kernel/debug/ 2>/dev/null | head -n 5
echo "--- devices_deferred 文件:"
if [ -f /sys/kernel/debug/devices_deferred ]; then
  echo "(存在) 内容行数: $(wc -l < /sys/kernel/debug/devices_deferred)"
  cat /sys/kernel/debug/devices_deferred
else
  echo "文件不存在"
fi
echo
echo "=== dmesg: panel/regulator/vpp/fxl ==="
dmesg | grep -i -E "panel|regulator|fxl|vpp|expander" | head -n 30
echo
echo "=== dsi_panel 活动节点属性(证明当前是RPi配置) ==="
ls /proc/device-tree/soc/drm/dsi_panel/ | head -n 30
echo "--- ACTIVE_WIDTH hex:"
hexdump -C /proc/device-tree/soc/drm/dsi_panel/ACTIVE_WIDTH 2>/dev/null
echo "--- command 属性存在?"
ls -la /proc/device-tree/soc/drm/dsi_panel/command 2>/dev/null || echo "(无command)"
echo
echo "=== syna_drm/panel 模块加载态 ==="
lsmod | grep -E "syna_drm|panel|attiny|ft5x06"
echo
echo "=== platform 设备里 panel 相关 ==="
ls /sys/bus/platform/devices/ | grep -i -E "panel|dsi"
