#!/bin/bash
P=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/drivers/synaptics/soc/berlin/modules/drm/panel/panel_dsi.c
DTS=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts
echo "════ 1. panel_dsi.c probe 的 supply 段 (260-330) ════"
sed -n '260,330p' "$P"
echo
echo "════ 2. connector/detect/status 相关 ════"
grep -n "detect\|connector_status\|connected" "$P" | head -n 15
echo
echo "════ 3. dts 726-775 行 (command 原文+节点尾) ════"
sed -n '726,775p' "$DTS"
