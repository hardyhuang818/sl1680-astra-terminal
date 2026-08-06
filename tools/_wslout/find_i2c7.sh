#!/bin/bash
K=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source
D=$K/arch/arm64/boot/dts/synaptics
echo "=== gpioi2c3 节点定义 ==="
grep -rn -B3 -A10 "gpioi2c3" $D/*.dts $D/*.dtsi 2>/dev/null | head -40

echo
echo "=== gpioi2c3_pmux 定义(哪两个 pad) ==="
grep -rn -A6 "gpioi2c3_pmux:" $D/*.dts $D/*.dtsi 2>/dev/null

echo
echo "=== SM pinctrl 里这些 pad 的 GPIO 号 ==="
F=$K/drivers/synaptics/pinctrl/berlin/pinctrl-dolphin.c
grep -n -A8 'BERLIN_PINCTRLCONF_GROUP("SM_TW3_SCL"\|BERLIN_PINCTRLCONF_GROUP("SM_TW3_SDA"' "$F" 2>/dev/null | grep -E '"SM_TW3|GPIO'
