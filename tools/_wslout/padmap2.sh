#!/bin/bash
K=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source
echo "=== 1. pinctrl@f7ea8000 的 compatible ==="
grep -rn -A4 "pinctrl@f7ea8000" $K/arch/arm64/boot/dts/synaptics/*.dtsi | head -20
echo
echo "=== 2. bg4ct.c 里 soc pinctrl 的完整 STS1 段(带 GPIO 注释) ==="
grep -n -A6 'BERLIN_PINCTRL_GROUP("STS1_' $K/drivers/pinctrl/berlin/berlin-bg4ct.c
echo
echo "=== 3. bg4ct.c 里这张表叫什么、绑哪个 compatible ==="
grep -n "compatible\|_pinctrl_data\|soc_pinctrl\|avio_pinctrl\|system_pinctrl" $K/drivers/pinctrl/berlin/berlin-bg4ct.c | head -25
echo
echo "=== 4. 原厂 platypus-rdk 的 gpio_keys(同族参考) ==="
grep -n -B4 -A24 "gpio_keys" $K/arch/arm64/boot/dts/synaptics/platypus-rdk.dts | head -45
echo
echo "=== 5. 我们 patch 的原始上下文(改前的 gpio_keys) ==="
P="/mnt/d/Claude code/Case6_Astra/meta-dlsdk/recipes-kernel/linux/files/0001-dolphin-rdk-td7800-tm10p5-lvds-panel.patch"
grep -n -B6 -A20 "gpio_keys\|vol_up\|vol_key" "$P" 2>/dev/null | head -60
echo
echo "=== 6. dolphin dts 里所有 &porta/&portb/&portc 的用法 ==="
grep -n "porta \|portb \|portc \|&porta\|&portb\|&portc" $K/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts | head -30
