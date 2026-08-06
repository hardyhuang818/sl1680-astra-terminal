#!/bin/bash
D=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts
echo "=== vol_key_pmux 定义 ==="
grep -n -B2 -A16 "vol_key_pmux:" "$D"
echo
echo "=== gpio_keys 节点 ==="
grep -n -B2 -A20 "gpio_keys" "$D" | head -40
echo
echo "=== 两个 hog ==="
grep -n -B6 -A26 "td7800_lcd_rst_hog" "$D"
echo
echo "=== 触摸节点 + INT ==="
grep -n -B4 -A14 "synaptics_tcm" "$D"
echo
echo "=== 别的 pmux 组是怎么写 function 的(样例) ==="
grep -n -A6 "_pmux:" "$D" | head -60
