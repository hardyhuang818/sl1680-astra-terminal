#!/bin/sh
echo "=== 1. tcm2 驱动探测日志 ==="
dmesg | grep -i -E "tcm|synaptics" | tail -n 12
echo
echo "=== 2. i2c-0: 0x2c 应显示 UU (被驱动占用) ==="
i2cdetect -y -r 0 2>/dev/null | grep "^20:"
echo
echo "=== 3. input 设备 ==="
ls /dev/input/
cat /proc/bus/input/devices 2>/dev/null | grep -B1 -A4 -i "tcm\|synaptics" | head -n 12
echo
echo "=== 4. 中断计数 (porta10) ==="
grep -i "tcm\|synap" /proc/interrupts
echo
echo "=== 5. 触摸事件采样 (8秒窗口, 现在摸屏幕!) ==="
T=$(cat /proc/bus/input/devices 2>/dev/null | grep -A4 -i "tcm\|synaptics" | grep -o "event[0-9]*" | head -n 1)
[ -z "$T" ] && T=event2
echo "监听 /dev/input/$T ..."
timeout 8 evtest /dev/input/$T 2>&1 | head -n 40
