#!/bin/sh
SM=/sys/kernel/debug/pinctrl/f7fe2c10.pinctrl-berlin-pinctrl
echo "===== pinmux-functions 里含 spi 的 ====="
grep -i spi "$SM/pinmux-functions"
echo
echo "===== pingroups 里的 SS0n ====="
grep -i "SS0n" "$SM/pingroups"
echo
echo "===== pinmux-pins 里的 SS0n/SS1n 当前归属 ====="
grep -i "SS0n\|SS1n" "$SM/pinmux-pins"
echo
echo "===== pinmux-select 用法（读它会打印格式）====="
cat "$SM/pinmux-select" 2>/dev/null | head -n 5
