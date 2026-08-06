#!/bin/bash
K=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source
OUT="/mnt/d/Claude code/Case6_Astra/meta-dlsdk/recipes-kernel/linux/files/0001-dolphin-rdk-td7800-tm10p5-lvds-panel.patch"
BK="/mnt/d/Claude code/Case6_Astra/TD7800_bringup_backup_2026-07-28/kernel-dts"

cd "$K" || exit 1
echo "=== 生成补丁 ==="
git diff -- arch/arm64/boot/dts/synaptics/dolphin-rdk.dts > /tmp/newpatch.diff
echo "  行数: $(wc -l < /tmp/newpatch.diff)"

# 去掉 git 的 index/mode 行，保持和原补丁一样的纯 unified diff 风格
python3 - <<'EOF'
import io, re
s = io.open("/tmp/newpatch.diff", encoding="utf-8").read()
lines = [l for l in s.splitlines(True)
         if not l.startswith(("diff --git ", "index ", "new file mode", "old mode", "new mode"))]
io.open("/tmp/newpatch.clean", "w", encoding="utf-8").write("".join(lines))
print("  清理后行数:", len(lines))
EOF

cp /tmp/newpatch.clean "$OUT"
echo "  已写入 $OUT"
echo
echo "=== 关键内容自检 ==="
python3 - "$OUT" <<'EOF'
import sys, io
s = io.open(sys.argv[1], encoding="utf-8").read()
checks = {
    "触摸节点 synaptics_tcm@2c":        "synaptics_tcm@2c" in s,
    "触摸 INT = porta 10":              "interrupts = <10 0x2008>" in s,
    "TD7800 面板时序 1280x720":          "dsi_panel" in s or "65300" in s,
    "TC358775 LVCFG=0x41":              "0x41" in s,
    "spi0 + spidev":                    "spidev" in s,
    "spi2_data_pmux 夺回 SDO/SDI":       "spi2_data_pmux" in s,
    "vol_up 已移除(注释在)":             "volume_up" in s,
    "复位脚改面板上拉的说明":            "TD7800 复位脚已改为面板侧 3.3V 上拉" in s,
    "★ 不应再有 hog":                    "gpio-hog" not in s,
    "★ 不应有 mipirst-gpios":            "mipirst-gpios" not in s,
}
ok = True
for k, v in checks.items():
    print(("  OK   " if v else "  ERR  ") + k); ok &= v
sys.exit(0 if ok else 1)
EOF
RC=$?
echo
echo "=== 同步一份最终 dts 到备份目录 ==="
cp "$K/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts" "$BK/dolphin-rdk.dts"
sha256sum "$K/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts" | cut -c1-64
exit $RC
