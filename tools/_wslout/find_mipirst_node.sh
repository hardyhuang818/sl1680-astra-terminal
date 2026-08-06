#!/bin/bash
K=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source
echo "════ mipirst 挂在哪个 DT 节点 ════"
sed -n '60,95p' $K/drivers/synaptics/soc/berlin/modules/avio/vpp/configs/vsxxx/drv_vpp_cfg.c
echo
echo "════ dolphin-rdk.dts 的 &avio/vpp 节点 ════"
D=$K/arch/arm64/boot/dts/synaptics
grep -n -A20 "^&avio" $D/dolphin-rdk.dts | head -n 26
echo
echo "════ STS1_CLK / STS1_VALD 的 GPIO 号 ════"
grep -n -A6 "STS1_CLK\|STS1_VALD" $K/drivers/synaptics/pinctrl/berlin/pinctrl-dolphin.c | grep -E "GROUP|GPIO"
