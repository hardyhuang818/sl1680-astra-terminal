#!/bin/sh
echo "=== A. 扩展器/GPIO 实际输出电平 ==="
cat /sys/kernel/debug/gpio 2>/dev/null | grep -A12 -i "fxl\|expander" | head -n 28
echo
echo "=== B. DSI/DPI 时钟实际状态 (期望 dpi≈65.3M 相关) ==="
grep -E "dpi|dsi|vclk|vpp" /sys/kernel/debug/clk/clk_summary 2>/dev/null | head -n 12
echo
echo "=== C. i2c-0 重扫 (0x2c=TD7800 touch=面板逻辑有电的探针) ==="
i2cdetect -y -r 0 2>/dev/null | grep -E "^20|^00"
echo
echo "=== D. 重启 weston 触发重新 modeset(重发桥片初始化) ==="
systemctl restart weston
sleep 4
systemctl is-active weston
for c in /sys/class/drm/card0-DSI-1; do echo "$c: $(cat $c/status) $(cat $c/enabled)"; done
echo
echo "=== E. 重启后 dmesg 新增 (最后15行) ==="
dmesg | tail -n 15
