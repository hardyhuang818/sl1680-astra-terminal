#!/bin/sh
# 刷完重启后的验证（板上跑）
echo "=== DTB 是否已换 (期望 ACTIVE_WIDTH=0x500=1280) ==="
hexdump -C /proc/device-tree/soc/drm/dsi_panel/ACTIVE_WIDTH
echo "=== command 长度 (期望 237 字节) ==="
wc -c < /proc/device-tree/soc/drm/dsi_panel/command
echo "=== DRM 连接器 ==="
for c in /sys/class/drm/card0-*; do echo "$c : $(cat $c/status 2>/dev/null) $(cat $c/enabled 2>/dev/null)"; done
echo "=== DSI-1 modes ==="
cat /sys/class/drm/card0-DSI-1/modes 2>/dev/null
echo "=== dmesg panel/dsi 相关 ==="
dmesg | grep -i -E "panel|dsi|mipi|vpp_cmd|Regulator" | tail -n 20
echo "=== 背光/扩展器 ==="
b=/sys/class/backlight/panel0-backlight
echo "brightness=$(cat $b/brightness)/$(cat $b/max_brightness) power=$(cat $b/bl_power)"
