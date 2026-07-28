#!/bin/sh
# 探测 J32 位敲 SPI 候选 GPIO：
#   J32.22 = GPIO37 → 猜测 sysfs 549 (chip1@544 + 5)
#   J32.31 = GPIO39 → 551
#   J32.32 = GPIO38 → 550
#   J32.18 = GPIO2  → 514 (chip0@512 + 2, 作 SDO 输入)
for n in 549 551 550; do
  [ -d /sys/class/gpio/gpio$n ] || echo $n > /sys/class/gpio/export 2>/dev/null
  if [ -d /sys/class/gpio/gpio$n ]; then
    echo out > /sys/class/gpio/gpio$n/direction 2>/dev/null
    echo 0 > /sys/class/gpio/gpio$n/value 2>/dev/null
    echo "gpio$n: export OK, direction=$(cat /sys/class/gpio/gpio$n/direction), value=$(cat /sys/class/gpio/gpio$n/value)"
  else
    echo "gpio$n: export 失败(被占用或不存在)"
  fi
done
n=514
[ -d /sys/class/gpio/gpio$n ] || echo $n > /sys/class/gpio/export 2>/dev/null
if [ -d /sys/class/gpio/gpio$n ]; then
  echo in > /sys/class/gpio/gpio$n/direction 2>/dev/null
  echo "gpio$n: export OK (输入), value=$(cat /sys/class/gpio/gpio$n/value)"
else
  echo "gpio$n: export 失败"
fi
echo "── 校准第一步: 只把 549 拉高 ──"
echo 1 > /sys/class/gpio/gpio549/value 2>/dev/null
echo "gpio549=1, gpio551=0, gpio550=0 已设置"
