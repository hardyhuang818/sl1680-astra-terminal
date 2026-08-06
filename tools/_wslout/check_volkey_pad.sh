#!/bin/bash
D=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/arch/arm64/boot/dts/synaptics
echo "════ vol_key_pmux 用的 pad 组 ════"
grep -n -A5 "vol_key_pmux" $D/dolphin-rdk.dts | head -n 10
echo
echo "════ gpio_keys 完整节点 ════"
sed -n '122,150p' $D/dolphin-rdk.dts
echo
echo "════ 对照 pinctrl: STS1_SOP=GPIO38, STS1_VALD=GPIO36, STS1_SD=GPIO37 ════"
echo "  若 vol_key_pmux = STS1_SOP + STS1_SD => volume 键就占着 J32.32(TP_RST)"
