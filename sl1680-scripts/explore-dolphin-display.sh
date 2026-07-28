#!/bin/bash
K=/home/astra/sdk/build-sl2619/tmp/work-shared/sl2619/kernel-source/arch/arm64/boot/dts/synaptics
SCH=/tmp/sl1680-sch.txt

echo "############ dolphin-rdk.dts &drm block (display routing) ############"
awk '/&drm *\{/,/^\};/' "$K/dolphin-rdk.dts" | head -80

echo
echo "############ dolphin bridge / expander / dsi nodes ############"
grep -nE 'expander|bridge|dsi_|i2c_bus|enable-gpio|reset-gpio' "$K/dolphin-rdk.dts" | head -40

echo
echo "############ dolphin-rdk.dts i2c0 children (expander lives here?) ############"
awk '/&i2c0 *\{/,/^\};/' "$K/dolphin-rdk.dts" | head -60

echo
echo "############ schematic: DSI connector pin context (lines 1140-1210) ############"
sed -n '1140,1210p' "$SCH"

echo
echo "############ schematic: expander0 I2C addr context ############"
grep -niE 'expander0|I2C Slave Address|0x4[0-9]|0x2[0-9]' "$SCH" | head -20
