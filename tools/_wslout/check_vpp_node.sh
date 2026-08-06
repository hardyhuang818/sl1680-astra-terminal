#!/bin/bash
D=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/arch/arm64/boot/dts/synaptics
echo "════ dolphin-rdk.dts 的 &avio 节点(我加 mipirst 的地方) ════"
sed -n '/^&avio {/,/^};/p' $D/dolphin-rdk.dts | head -n 30
echo
echo "════ dolphin.dtsi 里 avio/vpp 的 compatible ════"
grep -n -B2 -A8 'syna,berlin-vpp' $D/dolphin.dtsi | head -n 20
echo
echo "════ 触摸节点当前配置 ════"
sed -n '/synaptics_tcm@2c/,/};/p' $D/dolphin-rdk.dts
