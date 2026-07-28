#!/bin/sh
# GPIO10 三个候选 bank: 512+10 / 544+10 / 576+10
for n in 522 554 586; do
  [ -d /sys/class/gpio/gpio$n ] || echo $n > /sys/class/gpio/export 2>/dev/null
  if [ -d /sys/class/gpio/gpio$n ]; then
    echo in > /sys/class/gpio/gpio$n/direction 2>/dev/null
    echo "gpio$n = $(cat /sys/class/gpio/gpio$n/value)"
  else
    echo "gpio$n export失败"
  fi
done
