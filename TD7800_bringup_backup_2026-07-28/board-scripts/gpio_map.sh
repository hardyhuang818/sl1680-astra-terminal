#!/bin/sh
echo "=== gpiochip 底数/宽度/标签 ==="
for c in /sys/class/gpio/gpiochip*; do
  echo "$c base=$(cat $c/base) ngpio=$(cat $c/ngpio) label=$(cat $c/label)"
done
echo
echo "=== pinctrl 列表 ==="
ls /sys/kernel/debug/pinctrl/ 2>/dev/null
echo
echo "=== gpio-ranges ==="
for d in /sys/kernel/debug/pinctrl/*/; do
  echo "-- $d"
  cat "$d/gpio-ranges" 2>/dev/null | head -n 12
done
echo
echo "=== pinmux-pins 里 SPI2/GPIO 相关 (SoC主pinctrl) ==="
for d in /sys/kernel/debug/pinctrl/*/; do
  grep -i -E "spi2|SPI2" "$d/pinmux-pins" 2>/dev/null | head -n 8
done
echo
echo "=== 所有 pin 名单(找 GPIO 命名规律) ==="
for d in /sys/kernel/debug/pinctrl/*/; do
  echo "-- $d"
  head -n 25 "$d/pins" 2>/dev/null
done
