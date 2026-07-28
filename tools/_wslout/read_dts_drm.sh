#!/bin/bash
DTS=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts
echo "════ drm 相关段 ════"
grep -n -A6 "drm\|dsi\|panel\|backlight\|expander" "$DTS" | sed -n '1,90p'
echo
echo "════ include 链 ════"
grep -n "include" "$DTS"
