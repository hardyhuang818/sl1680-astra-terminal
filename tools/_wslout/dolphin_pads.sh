#!/bin/bash
K=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source
echo "=== 1. 谁实现了 syna,dolphin-soc-pinctrl ==="
grep -rn "dolphin-soc-pinctrl" $K/drivers/ 2>/dev/null | head -5
F=$(grep -rl "dolphin-soc-pinctrl" $K/drivers/ 2>/dev/null | head -1)
echo "  文件: $F"
echo
echo "=== 2. 该文件里的 STS1 段 ==="
grep -n -A8 '"STS1_' "$F" 2>/dev/null
echo
echo "=== 3. 该文件里 GPIO3x-4x 的全部 pad(找 GPIO36/38/39) ==="
grep -n -B4 "GPIO3[0-9] \|GPIO4[0-5] " "$F" 2>/dev/null | grep -E '"|GPIO' | head -60
echo
echo "=== 4. 整张 soc 表里 group 顺序 + GPIO 注释(索引 10~25) ==="
grep -n 'BERLIN_PINCTRL_GROUP("' "$F" 2>/dev/null | head -45
