#!/bin/bash
K=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source
echo "════ 1. mipirst 的 DT 属性名 ════"
grep -n -B3 -A20 "int avio_module_mipirst_get_gpio_handle" \
  $K/drivers/synaptics/soc/berlin/modules/avio/avio_core.c
echo
echo "════ 2. J32.32/33 的 pad 组名（含 GPIO38/47/36 的完整条目）════"
P=$K/drivers/synaptics/pinctrl/berlin/pinctrl-dolphin.c
sed -n '60,80p;110,135p' $P
echo
echo "════ 3. drv_vpp.c 里复位脚的时序 ════"
sed -n '140,150p;450,460p;1040,1055p;1070,1085p' $K/drivers/synaptics/soc/berlin/modules/avio/vpp/drv_vpp.c
