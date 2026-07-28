#!/bin/bash
K=/home/astra/sdk/build-sl2619/tmp/work-shared/sl2619/kernel-source/arch/arm64/boot/dts/synaptics

echo "############ which i2c holds expander0/expander1 ############"
awk 'NR>=430 && NR<=520' "$K/dolphin-rdk.dts" | grep -nE '&i2c|expander|rpi_panel|reg = |gpio@'

echo
echo "############ panel0-backlight + enable-gpio node (lines 60-120) ############"
sed -n '60,120p' "$K/dolphin-rdk.dts"

echo
echo "############ dolphin-haier-panel-overlay.dtso (another MIPI panel example) ############"
sed -n '25,90p' "$K/dolphin-haier-panel-overlay.dtso"
