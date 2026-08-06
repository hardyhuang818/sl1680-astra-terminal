#!/bin/bash
K=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source
F=$K/drivers/synaptics/pinctrl/berlin/pinctrl-dolphin.c
echo "=== 标尺 1: USB2_DRV_VBUS (= portb line 23, 实测稳定驱动) ==="
grep -n -A6 '"USB2_DRV_VBUS"' "$F" | head -12
echo
echo "=== 标尺 2: SDIO_WP (= sdhci1_gpio_pmux) ==="
grep -n -A6 '"SDIO_WP"' "$F" | head -10
echo
echo "=== 标尺 3: TW0_SCL/SDA (i2c0, 已知工作) ==="
grep -n -A5 '"TW0_SCL"' "$F" | head -8
echo
echo "=== 待测: STS1_SOP / STS1_VALD / STS1_CLK ==="
grep -n -A3 '"STS1_SOP"\|"STS1_VALD"\|"STS1_CLK"' "$F" | grep -E '"STS1|GPIO'
echo
echo "=== 触摸 INT: I2S2_DI1 (DTS 说 = porta line 10) ==="
grep -n -A6 '"I2S2_DI1"' "$F" | head -10
echo
echo "=== dolphin.dtsi: 三个 gpio 控制器与 porta/portb/portc 标签 ==="
grep -n -A6 "gpio@0800\|gpio@0c00\|gpio@2400" $K/arch/arm64/boot/dts/synaptics/dolphin.dtsi | grep -E "gpio@|porta:|portb:|portc:|reg =|compatible"
echo
echo "=== DTS 里 &portb 23 / &portb 12 的用处(对照锚点) ==="
grep -n "portb 23\|portb 12\|portb 7\|portb 6\|portb 4" $K/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts
