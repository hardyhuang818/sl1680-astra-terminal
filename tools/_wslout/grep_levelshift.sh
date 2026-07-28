#!/bin/bash
K=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/arch/arm64/boot/dts/synaptics
echo "════ 1. levelshift 在 dts/dtsi 里 ════"
grep -rn -B6 -A8 -i "levelshift" $K/dolphin-rdk.dts $K/dolphin.dtsi 2>/dev/null
echo
echo "════ 2. TW0/i2c0 相关节点 ════"
grep -rn -B2 -A10 "i2c0\|tw0\|TW0" $K/dolphin-rdk.dts | head -n 40
