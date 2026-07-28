#!/bin/bash
D=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/arch/arm64/boot/dts/synaptics/dolphin.dtsi
grep -n -B2 -A8 "f7fe2c10" $D
echo ────
grep -n "pinctrl" $D | head -20
