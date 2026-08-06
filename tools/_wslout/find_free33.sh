#!/bin/bash
K=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source
F=$K/drivers/synaptics/pinctrl/berlin/pinctrl-dolphin.c
D=$K/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts

echo "=== 候选 pad 的 GPIO 号 ==="
for g in SM_SPI2_SS1n SM_SPI2_SS0n I2S1_DO2 SM_SPI2_SS2n; do
  echo "--- $g ---"
  grep -n -A8 "BERLIN_PINCTRLCONF_GROUP(\"$g\"" "$F" | grep -E "GROUP\(|GPIO[0-9]|\"pwm\"|\"gpio\""
done

echo
echo "=== 这些 pad 在 dts 里被谁 mux 走了 ==="
for g in SM_SPI2_SS1n SM_SPI2_SS0n I2S1_DO2 SM_SPI2_SS2n; do
  printf "  %-16s " "$g"
  grep -c "\"$g\"" "$D"
done
echo "  (0 = dts 里没人声明, 可能空闲)"

echo
echo "=== dts 里各 pmux 组包含的 SM_SPI2/I2S1_DO2 ==="
grep -n "SM_SPI2\|I2S1_DO2" "$D"

echo
echo "=== SM gpiochip base(f7fc8000) ==="
echo "  SM GPIO n -> gpio(608+n)"
