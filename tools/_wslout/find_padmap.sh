#!/bin/bash
K=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source
echo "=== 1. berlin pinctrl 驱动里的 pad 表 ==="
ls $K/drivers/pinctrl/berlin/ 2>/dev/null
F=$(grep -rl "STS1_SOP" $K/drivers/pinctrl/ 2>/dev/null | head -3)
echo "  含 STS1_SOP 的文件: $F"
for f in $F; do
  echo "--- $f ---"
  grep -n -B12 -A12 "STS1_CLK" "$f" | head -70
done

echo
echo "=== 2. dts 里所有 STS1 出现处 ==="
grep -rn "STS1" $K/arch/arm64/boot/dts/synaptics/ 2>/dev/null | head -20

echo
echo "=== 3. 原厂 dts 里 vol_up/vol_down 原始定义(备份文件) ==="
B=$K/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts.pre_td7800
[ -f "$B" ] && grep -n -B6 -A24 "gpio_keys" "$B" | head -50 || echo "  无备份"

echo
echo "=== 4. portb/porta/portc 在 dts 里的定义(base 与 label) ==="
grep -rn -A8 "porta:\|portb:\|portc:" $K/arch/arm64/boot/dts/synaptics/*.dtsi 2>/dev/null | head -40
