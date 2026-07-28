#!/bin/sh
# TM10.5-TD7800 点不亮诊断：地面真相采集
echo "=== 1. 系统 ==="
uname -r; uptime; date
echo
echo "=== 2. /boot 里的 overlay 文件 ==="
ls -la /boot/*.dtbo 2>/dev/null || echo "(no dtbo in /boot)"
echo
echo "=== 3. 活动设备树里有没有 panel/dsi 节点 ==="
ls /proc/device-tree/soc*/ 2>/dev/null | grep -i -E "dsi|panel|lvds" || echo "(soc下无dsi/panel节点名)"
find /proc/device-tree -maxdepth 3 -name "*dsi*" 2>/dev/null | head -5
find /proc/device-tree -maxdepth 3 -name "*panel*" 2>/dev/null | head -5
echo "--- drm 节点 disp-mode:"
if [ -f /proc/device-tree/soc/drm/disp-mode ]; then
  od -An -td4 /proc/device-tree/soc/drm/disp-mode
else
  find /proc/device-tree -maxdepth 3 -name "disp-mode" 2>/dev/null
fi
echo "--- dsi_panel 节点存在?"
find /proc/device-tree -maxdepth 4 -type d -name "*dsi_panel*" 2>/dev/null || echo "(无 dsi_panel 节点)"
echo
echo "=== 4. DRM 连接器状态 ==="
for c in /sys/class/drm/card*-*; do
  [ -e "$c/status" ] && echo "$c : $(cat $c/status) $(cat $c/enabled 2>/dev/null)"
done
echo
echo "=== 5. dmesg 关键行 ==="
dmesg | grep -i -E "dsi|mipi|panel|lvds|tc358|bridge" | tail -30
echo
echo "=== 6. i2c-0 扫描 (期望: 触摸2c=面板TP有电+线通; 0f=TC358775若接了I2C) ==="
i2cdetect -y 0 2>&1
echo
echo "=== 7. IO 扩展器 / 背光状态 ==="
ls /sys/class/gpio/ 2>/dev/null
cat /sys/kernel/debug/gpio 2>/dev/null | head -40
echo "--- backlight:"
for b in /sys/class/backlight/*; do
  [ -e "$b" ] && echo "$b brightness=$(cat $b/brightness 2>/dev/null)/$(cat $b/max_brightness 2>/dev/null) power=$(cat $b/bl_power 2>/dev/null)"
done
echo
echo "=== 8. 当前跑的服务(显示相关) ==="
systemctl is-active dl-face astra-voice 2>/dev/null
ps | grep -E "dl_face|weston|gst" | grep -v grep | head -5
