#!/bin/bash
K=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source
echo "════ 1. J32.32/33 对应的 pad（GPIO38/47 与 GPIO36/EXP_0_7）════"
P=$K/drivers/synaptics/pinctrl/berlin/pinctrl-dolphin.c
grep -n "GPIO38\|GPIO47\|GPIO36" $P | head -n 12
echo
echo "════ 2. 面板驱动怎么找复位 GPIO ════"
grep -rn "mipirst" $K/drivers/synaptics/soc/berlin/modules/ 2>/dev/null | head -n 8
echo "── 函数实现:"
F=$(grep -rln "avio_module_mipirst_get_gpio_handle" $K/drivers/synaptics/ 2>/dev/null | grep -v "\.h$" | head -n 1)
echo "file: $F"
[ -n "$F" ] && grep -n -A25 "avio_module_mipirst_get_gpio_handle" "$F" | head -n 40
echo
echo "════ 3. set_gpio_val 实现(看怎么用) ════"
grep -rn -A12 "avio_module_mipirst_set_gpio_val" $K/drivers/synaptics/ 2>/dev/null | grep -v "\.h:" | head -n 20
