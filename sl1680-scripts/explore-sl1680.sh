#!/bin/bash
# Explore SL1680 (dolphin) display + i2c structure for TD7800 LVDS integration.
K=/home/astra/sdk/build-sl2619/tmp/work-shared/sl2619/kernel-source/arch/arm64/boot/dts/synaptics

echo "############ dolphin-rdk.dts : display + i2c ############"
grep -niE 'dsi|panel|lvds|bridge|mipi|i2c|vop|drm|status' "$K/dolphin-rdk.dts" 2>/dev/null | head -80

echo
echo "############ &dsi / drm block in dolphin-rdk.dts ############"
sed -n '1,60p' "$K/dolphin-rdk.dts"

echo
echo "############ dolphin-ws-1080p-panel-overlay.dtso (MIPI panel template) ############"
cat "$K/dolphin-ws-1080p-panel-overlay.dtso" 2>/dev/null

echo
echo "############ dolphin.dtsi : i2c + dsi labels ############"
grep -nE 'i2c[0-9]+:|dsi:|dsi@|drm:|vpp|vop' "$K/dolphin.dtsi" 2>/dev/null | head -40
