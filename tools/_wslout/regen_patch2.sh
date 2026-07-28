#!/bin/bash
# 用 TD7800 工作开始前的基线 dts 作为 a/ 侧，生成完整补丁（不是增量）
K=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts
BK="/mnt/d/Claude code/Case6_Astra/TD7800_bringup_backup_2026-07-28/kernel-dts"
BASE="$BK/dolphin-rdk.dts.pre_td7800"
OUT="/mnt/d/Claude code/Case6_Astra/meta-dlsdk/recipes-kernel/linux/files/0001-dolphin-rdk-td7800-tm10p5-lvds-panel.patch"

echo "=== 基线自检：应该还是树莓派屏配置 ==="
grep -c "800x480\|TC358762\|rpi\|raspberry" "$BASE" 2>/dev/null
grep -n "clock-frequency\|Lanes\|compatible.*panel" "$BASE" 2>/dev/null | head -n 6
echo "  基线大小 $(wc -c < "$BASE")  当前 dts $(wc -c < "$K")"
echo "  基线里有没有我们的东西(都应为 0):"
for k in synaptics_tcm@2c spi2_data_pmux td7800 65300; do
  echo "    $k: $(grep -ci "$k" "$BASE")"
done

echo
echo "=== 生成完整补丁 ==="
D=$(mktemp -d)
mkdir -p "$D/a/arch/arm64/boot/dts/synaptics" "$D/b/arch/arm64/boot/dts/synaptics"
cp "$BASE" "$D/a/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts"
cp "$K"    "$D/b/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts"
cd "$D" && diff -u a/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts \
                   b/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts > /tmp/full.diff
echo "  行数: $(wc -l < /tmp/full.diff)"
cp /tmp/full.diff "$OUT"
rm -rf "$D"

echo
echo "=== 内容自检 ==="
python3 - "$OUT" <<'EOF'
import sys, io
s = io.open(sys.argv[1], encoding="utf-8").read()
checks = {
    "触摸节点 synaptics_tcm@2c":       "synaptics_tcm@2c" in s,
    "触摸 INT = porta 10":             "interrupts = <10 0x2008>" in s,
    "面板 pclk 65300":                 "65300" in s,
    "TC358775 LVCFG=0x41":             "0x9C 0x04 0x41" in s or "0x41" in s,
    "spidev 调试通道":                 "spidev" in s,
    "spi2_data_pmux 夺回 SDO/SDI":      "spi2_data_pmux" in s,
    "vol_up 移除说明":                 "volume_up" in s,
    "复位脚改面板上拉的说明":           "TD7800 复位脚已改为面板侧 3.3V 上拉" in s,
    "★ 不应再有 gpio-hog":              "gpio-hog" not in s,
    "★ 不应有 mipirst-gpios":           "mipirst-gpios" not in s,
    "★ 补丁头是 a/arch 路径":           s.startswith("--- a/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts"),
}
ok = True
for k, v in checks.items():
    print(("  OK   " if v else "  ERR  ") + k); ok &= v
sys.exit(0 if ok else 1)
EOF
RC=$?

echo
echo "=== 干跑验证：基线 + 补丁 == 当前 dts ? ==="
T=$(mktemp -d); mkdir -p "$T/arch/arm64/boot/dts/synaptics"
cp "$BASE" "$T/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts"
( cd "$T" && patch -p1 --dry-run < "$OUT" >/dev/null 2>&1 && patch -p1 -s < "$OUT" )
if cmp -s "$T/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts" "$K"; then
  echo "  ★ 完全一致 —— 补丁可重放"
else
  echo "  ✗ 不一致!"; RC=1
fi
rm -rf "$T"

echo
echo "sha256(最终 dts) = $(sha256sum "$K" | cut -c1-64)"
cp "$K" "$BK/dolphin-rdk.dts"
exit $RC
