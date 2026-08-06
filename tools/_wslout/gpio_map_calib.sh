#!/bin/bash
D=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/arch/arm64/boot/dts/synaptics
echo "════ 1. volume 键在哪个 port(标定 base512) ════"
grep -n -A14 "gpio_keys" $D/dolphin-rdk.dts | head -n 24
echo
echo "════ 2. 其它已知 GPIO 的 port 归属 ════"
grep -n "hdmitx5v\|vmmc_sdhc" $D/dolphin-rdk.dts | head -n 6
grep -n -B3 -A6 "hdmitx5v" $D/dolphin-rdk.dts | head -n 16
echo
echo "════ 3. portb/portc 的父控制器地址 ════"
grep -n -B12 "portb: gpio-port" $D/dolphin.dtsi | grep -E "gpio[0-9]: gpio@|reg ="
grep -n -B12 "portc: gpio-port" $D/dolphin.dtsi | grep -E "gpio[0-9]: gpio@|reg ="
grep -n -B12 "porta: gpio-port" $D/dolphin.dtsi | grep -E "gpio[0-9]: gpio@|reg ="
