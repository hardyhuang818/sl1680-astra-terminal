#!/bin/sh
echo "=== 读空前 (各采样5次) ==="
for n in 522 554 586; do
  v=""
  for i in 1 2 3 4 5; do v="$v$(cat /sys/class/gpio/gpio$n/value)"; done
  echo "gpio$n: $v"
done
echo
echo "=== 从 0x2C 读报文 (排空 FIFO) ==="
which i2ctransfer >/dev/null 2>&1 && echo "(有 i2ctransfer)" || echo "(无 i2ctransfer, 用 i2cget/dd)"
for k in 1 2 3 4 5 6 7 8; do
  i2ctransfer -y 0 r32@0x2c 2>/dev/null | head -c 100
  echo
done
echo
echo "=== 读空后 ==="
for n in 522 554 586; do
  v=""
  for i in 1 2 3 4 5; do v="$v$(cat /sys/class/gpio/gpio$n/value)"; done
  echo "gpio$n: $v"
done
