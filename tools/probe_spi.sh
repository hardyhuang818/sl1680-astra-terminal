#!/bin/sh
# EB7928 走 SPI 前的地面真相：spidev 在不在、SPI2 引脚有没有被 ebi2c 占着
echo "===== 基本 ====="
echo "uptime: $(uptime | sed 's/^ *//')"
echo "kernel: $(uname -r)"

echo
echo "===== spidev 设备节点 ====="
ls -l /dev/spidev* 2>/dev/null || echo "  (无 /dev/spidev* —— DTS 里没有 spidev 节点，或驱动没编)"

echo
echo "===== SPI 控制器 ====="
ls /sys/class/spi_master/ 2>/dev/null || echo "  (无 spi_master)"
for m in /sys/class/spi_master/spi*; do
  [ -e "$m" ] || continue
  echo "  $m -> $(readlink -f $m | sed 's#.*/devices/##')"
done
echo "-- 已绑定的 spi 从设备 --"
ls /sys/bus/spi/devices/ 2>/dev/null || echo "  (无)"
echo "-- spidev 驱动 --"
ls /sys/bus/spi/drivers/ 2>/dev/null
grep -q spidev /proc/modules 2>/dev/null && echo "  spidev 是模块且已加载" || true
[ -d /sys/bus/spi/drivers/spidev ] && echo "  spidev 驱动在位" || echo "  ⚠ 无 spidev 驱动"

echo
echo "===== ebi2c 节点（借用了 SPI2 的 SS0n/SS1n）是否还在 ====="
if [ -d /proc/device-tree/ebi2c ]; then
  echo "  ⚠ ebi2c 节点【仍在】—— SPI2 的片选引脚被它当 GPIO 占着，必须先移除"
  echo "     compatible: $(tr -d '\0' < /proc/device-tree/ebi2c/compatible 2>/dev/null)"
else
  echo "  ✓ 无 ebi2c 节点"
fi
echo "-- i2c-gpio 总线（ebi2c 若生效会多出一条）--"
for b in /sys/bus/i2c/devices/i2c-*; do
  n=$(cat $b/name 2>/dev/null)
  echo "  $(basename $b): $n"
done

echo
echo "===== device-tree 里所有 spi 节点 ====="
for d in /proc/device-tree/*/spi*  /proc/device-tree/spi*; do
  [ -d "$d" ] || continue
  st=$(tr -d '\0' < "$d/status" 2>/dev/null)
  cp=$(tr -d '\0' < "$d/compatible" 2>/dev/null)
  echo "  $(echo $d | sed 's#/proc/device-tree/##')  status=${st:-(默认okay)}  compatible=$cp"
  for c in "$d"/*/; do
    [ -d "$c" ] || continue
    ccp=$(tr -d '\0' < "$c/compatible" 2>/dev/null)
    [ -n "$ccp" ] && echo "      └ $(basename $c)  compatible=$ccp"
  done
done

echo
echo "===== 触摸/面板 SPI 相关 ====="
echo "触摸中断: $(grep -i synaptics_tcm /proc/interrupts | awk '{print $2+$3+$4+$5}')"
echo "kiosk=$(systemctl is-active astra-kiosk) webctl=$(systemctl is-active astra-webctl)"
