#!/bin/bash
K=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source
echo "════ 1. 找 SPI2_SS0n 组名定义 (dolphin pinctrl) ════"
F=$(grep -rln "SPI2_SS0n" $K/drivers 2>/dev/null | head -2)
echo "file: $F"
for f in $F; do
  echo "── $f 里 SPI2 相关 ──"
  grep -n -B1 -A3 "SPI2" "$f" | head -40
done
echo
echo "════ 2. 同文件里 GPIO 函数命名样例 ════"
for f in $F; do
  grep -n "\"gpio\"" "$f" | head -6
done
