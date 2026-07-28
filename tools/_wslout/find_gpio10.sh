#!/bin/bash
K=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source
echo "════ pinctrl-dolphin.c 里 GPIO10 的组 ════"
grep -n -B4 "GPIO10 \*/" $K/drivers/synaptics/pinctrl/berlin/pinctrl-dolphin.c | head -20
echo
echo "════ dtsi 的 SoC gpio 节点标签 ════"
grep -n -B2 -A10 "porta\|portb\|portc" $K/arch/arm64/boot/dts/synaptics/dolphin.dtsi | head -50
