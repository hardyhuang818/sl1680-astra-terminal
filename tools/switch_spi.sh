#!/bin/sh
# EB7928 改走 SPI：释放 ebi2c 占的 SS0n 片选 -> pinmux 还给 spi2（运行时，不重建boot）
echo "===== 0. 现状 ====="
ls /sys/bus/platform/devices/ | grep -i ebi2c
echo "i2c-gpio 驱动绑定的设备: $(ls /sys/bus/platform/drivers/i2c-gpio/ | grep -v -E 'bind|uevent|module')"

echo
echo "===== 1. unbind ebi2c（释放 portd16/17 两个 GPIO + pinctrl）====="
if [ -e /sys/bus/platform/drivers/i2c-gpio/ebi2c ]; then
  echo ebi2c > /sys/bus/platform/drivers/i2c-gpio/unbind && echo "  已 unbind"
else
  echo "  (本来就没绑定)"
fi
[ -d /sys/class/i2c-adapter/i2c-7 ] && echo "  ⚠ i2c-7 还在" || echo "  ✓ i2c-7 已消失"

echo
echo "===== 2. debugfs pinmux：SM_SPI2_SS0n 还给 spi2 ====="
mount | grep -q debugfs || mount -t debugfs none /sys/kernel/debug
for d in /sys/kernel/debug/pinctrl/*/; do
  echo "  pinctrl 实例: $d"
done
# 找 SM 域的 pinctrl（组名里有 SM_SPI2）
SM=""
for d in /sys/kernel/debug/pinctrl/*/; do
  if grep -q "SM_SPI2_SS0n" "$d/pingroups" 2>/dev/null; then SM="$d"; fi
done
if [ -z "$SM" ]; then echo "  ❌ 找不到含 SM_SPI2_SS0n 的 pinctrl"; exit 1; fi
echo "  SM pinctrl = $SM"
echo "-- 当前 SS0n/SS1n 状态 --"
grep -A2 "SM_SPI2_SS0n\|SM_SPI2_SS1n" "$SM/pinmux-pins" 2>/dev/null | head -8
grep "SM_SPI2_SS0n\|SM_SPI2_SS1n" "$SM/pinmux-select" 2>/dev/null
if [ -w "$SM/pinmux-select" ]; then
  echo "spi2 SM_SPI2_SS0n" > "$SM/pinmux-select" && echo "  ✓ SS0n -> spi2 已下发"
else
  echo "  ❌ pinmux-select 不可写（内核没开 CONFIG_DEBUG_PINCTRL 写接口）"
fi
echo "-- 之后 --"
grep -B1 -A1 "SS0n" "$SM/pinmux-pins" 2>/dev/null | head -6

echo
echo "===== 3. spidev 现状 ====="
ls -l /dev/spidev*
echo "===== 完成 ====="
