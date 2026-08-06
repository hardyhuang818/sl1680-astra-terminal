#!/bin/sh
SM=/sys/kernel/debug/pinctrl/f7fe2c10.pinctrl-berlin-pinctrl
dmesg -C 2>/dev/null
echo "尝试 1: printf 无换行 'spi2 SM_SPI2_SS0n'"
printf "spi2 SM_SPI2_SS0n" > "$SM/pinmux-select" 2>&1 && echo "  ✓ 成功" || echo "  ✗ 失败"
dmesg | tail -3
echo
echo "尝试 2: 反序 'SM_SPI2_SS0n spi2'"
printf "SM_SPI2_SS0n spi2" > "$SM/pinmux-select" 2>&1 && echo "  ✓ 成功" || echo "  ✗ 失败"
dmesg | tail -3
echo
echo "===== SS0n 当前归属 ====="
grep -i "SS0n" "$SM/pinmux-pins"
