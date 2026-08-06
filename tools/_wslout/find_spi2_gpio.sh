#!/bin/bash
F=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/drivers/synaptics/pinctrl/berlin/pinctrl-dolphin.c
echo "=== SM_SPI2_SS1n / SS3n / SM_SPI2_SS2n 的 GPIO 号 ==="
grep -n -A6 'BERLIN_PINCTRLCONF_GROUP("SM_SPI2_SS1n"\|BERLIN_PINCTRLCONF_GROUP("SM_SPI2_SS3n"\|BERLIN_PINCTRLCONF_GROUP("SM_SPI2_SS2n"' "$F" | grep -E '"SM_SPI2|GPIO'
echo
echo "=== SM 域 GPIO 归哪个 gpiochip(f7fc8000, base 608) ==="
echo "  SM GPIO n -> gpio (608 + n)"
echo
echo "=== 这两个脚在 dts 里被谁用了吗 ==="
D=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts
grep -n "SS1n\|SS3n" "$D"
