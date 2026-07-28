#!/bin/bash
K=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source
D=$K/arch/arm64/boot/dts/synaptics
echo "════ 1. dolphin.dtsi 里的 spi 控制器 ════"
grep -n -B2 -A14 "spi@\|spi1\|spi2\|ssi" $D/dolphin.dtsi | head -60
echo
echo "════ 2. pinctrl 驱动里 SPI2 相关组和 gpio 映射 ════"
P=$(grep -rln "SPI2" $K/drivers/pinctrl/ 2>/dev/null | head -2)
echo "files: $P"
for f in $P; do
  grep -n "SPI2" "$f" | head -12
done
echo
echo "════ 3. GPIO 组名规律 (同一个驱动文件里) ════"
for f in $P; do
  grep -n "\"GPIO\|gpio.*37\|gpio.*38\|gpio.*39" "$f" | head -12
done
