#!/bin/sh
# SPI 升级前置：确认/重做 ebi2c 释放 + SS0n pinmux + spidev 在位
echo "uptime: $(uptime | sed 's/^ *//')"
SM=/sys/kernel/debug/pinctrl/f7fe2c10.pinctrl-berlin-pinctrl
mount | grep -q debugfs || mount -t debugfs none /sys/kernel/debug

if [ -e /sys/bus/platform/drivers/i2c-gpio/ebi2c ]; then
  echo ebi2c > /sys/bus/platform/drivers/i2c-gpio/unbind && echo "ebi2c: 已 unbind"
else
  echo "ebi2c: 未绑定（重启后未生效或已 unbind）"
fi
[ -d /sys/class/i2c-adapter/i2c-7 ] && echo "⚠ i2c-7 仍在" || echo "✓ i2c-7 不在"

printf "SM_SPI2_SS0n spi2" > "$SM/pinmux-select" 2>/dev/null && echo "✓ SS0n -> spi2" || echo "SS0n pinmux 写入失败（可能已是 spi2）"
ls -l /dev/spidev0.0
echo "===== scanmode ====="
cd /home/voice
python3 eb7928_spi.py scanmode
