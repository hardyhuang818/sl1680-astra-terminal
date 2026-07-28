#!/bin/bash
# 从 .pre_td7800 基线生成完整补丁 → meta-dlsdk
K=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/arch/arm64/boot/dts/synaptics
OUT="/mnt/d/Claude code/Case6_Astra/meta-dlsdk/recipes-kernel/linux/files"
mkdir -p "$OUT"
P="$OUT/0001-dolphin-rdk-td7800-tm10p5-lvds-panel.patch"
diff -u --label a/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts \
        --label b/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts \
        "$K/dolphin-rdk.dts.pre_td7800" "$K/dolphin-rdk.dts" > "$P"
echo "patch 行数: $(wc -l < "$P")"
head -n 5 "$P"
echo "..."
grep -c "^+" "$P" | xargs echo "新增行:"
# 关键内容抽查
for k in "ACTIVE_WIDTH = <1280>" "Byte_clk = <65300>" "0x41 0x00 0x00 0x00" "spi2_data_pmux" "rohm,dh2228fv"; do
  grep -q "$k" "$P" && echo "✓ $k" || echo "✗ $k 不在补丁里!"
done
