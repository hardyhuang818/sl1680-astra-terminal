#!/bin/sh
echo "=== 1. pinmux (期望 SDO/SDI func=0, 由DTB固化) ==="
V=$(devmem 0xf7fe2c14)
echo "f7fe2c14 = $V"
echo "=== 2. spidev 节点 ==="
modprobe spidev 2>/dev/null
ls /dev/spidev* 2>/dev/null
echo "=== 3. 显示状态 ==="
echo "DSI-1: $(cat /sys/class/drm/card0-DSI-1/status) $(cat /sys/class/drm/card0-DSI-1/enabled)"
cat /sys/class/drm/card0-DSI-1/modes 2>/dev/null
echo "=== 4. 触摸探针 ==="
i2cdetect -y -r 0 2>/dev/null | grep "^20:"
echo "=== 5. weston ==="
systemctl is-active weston
echo
echo "★★ 看屏: 新配置(DSI+33%带宽余量)下 Weston 桌面出来没有? ★★"
