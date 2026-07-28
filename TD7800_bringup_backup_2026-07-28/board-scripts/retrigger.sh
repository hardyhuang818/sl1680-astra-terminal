#!/bin/sh
echo "=== 1. i2c-0 扫描 (0x2c = TD7800 touch) ==="
i2cdetect -y -r 0 2>/dev/null
echo
echo "=== 2. 重发桥片初始化 (weston restart -> re-modeset) ==="
systemctl restart weston
sleep 5
echo "weston: $(systemctl is-active weston)"
echo "DSI-1: $(cat /sys/class/drm/card0-DSI-1/status) $(cat /sys/class/drm/card0-DSI-1/enabled)"
echo
echo "=== 3. 再扫一次 i2c (排除 modeset 影响) ==="
i2cdetect -y -r 0 2>/dev/null | grep -E "^20:|^00:"
echo
echo "=== 4. crtc 状态 ==="
grep -E "^crtc|active=" /sys/kernel/debug/dri/0/state | head -n 6
echo
echo "=== 5. dmesg 最新10行 ==="
dmesg | tail -n 10
