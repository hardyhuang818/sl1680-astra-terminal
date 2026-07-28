#!/bin/bash
D=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/arch/arm64/boot/dts/synaptics/dolphin.dtsi
grep -n -B14 "porta: gpio-port" $D | grep -E "gpio@|reg =|porta"
echo ──
grep -n -B14 "portb: gpio-port" $D | grep -E "gpio@|reg =|portb"
echo ──
grep -n -B14 "portc: gpio-port" $D | grep -E "gpio@|reg =|portc"
