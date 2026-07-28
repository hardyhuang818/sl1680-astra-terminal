#!/bin/sh
echo "=== 重启持久性自检 ==="
echo "[1] uptime: $(uptime | cut -d, -f1)"
echo "[2] 显示: DSI-1 = $(cat /sys/class/drm/card0-DSI-1/status) $(cat /sys/class/drm/card0-DSI-1/enabled), mode=$(cat /sys/class/drm/card0-DSI-1/modes | head -n 1)"
echo "[3] 触摸驱动: i2c 0x2c = $(i2cdetect -y -r 0 2>/dev/null | grep '^20:' | awk '{print $14}') (UU=驱动接管)"
echo "[4] 触摸中断: $(grep synaptics_tcm /proc/interrupts | awk '{print "IRQ"$1" 计数"$2}')"
echo "[5] 触摸校准: $(udevadm info /dev/input/event2 2>/dev/null | grep -o 'LIBINPUT_CALIBRATION_MATRIX=.*')"
echo "[6] weston: $(systemctl is-active weston), 翻转=$(grep -A2 'name=DSI-1' /etc/xdg/weston/weston.ini | grep transform)"
echo "[7] 时区: $(date '+%Z %Y-%m-%d %H:%M:%S')"
echo "[8] SPI 调试通道: $(modprobe spidev 2>/dev/null; ls /dev/spidev0.0 2>/dev/null || echo 缺失)"
echo "[9] pinmux: $(devmem 0xf7fe2c14)  (期望 0x00005A01)"
echo
echo "★ 屏上应该: 正向 Weston 桌面 + 右上角 CST 时钟; 触摸桌面应有响应"
