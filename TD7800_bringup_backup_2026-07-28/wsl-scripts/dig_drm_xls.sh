#!/bin/bash
K=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/drivers/synaptics/soc/berlin/modules/drm
echo "════ 1. drm 模块目录 ════"
ls "$K" | head -30
echo
echo "════ 2. command 属性解析 ════"
grep -rn -B2 -A25 '"command"' "$K" 2>/dev/null | head -60
echo
echo "════ 3. 0xff 延时标记语义 ════"
grep -rn -B3 -A8 "0xff\b\|0xFF\b" "$K"/*panel*.c "$K"/*dsi*.c 2>/dev/null | grep -A8 -B3 -i "delay\|sleep" | head -30
echo
echo "════ 4. XLS Code 表 (前120行) ════"
python3 - <<'EOF'
import xlrd
wb = xlrd.open_workbook("/mnt/d/Claude code/Case6_Astra/MIPI to LVDS board-1/LAMTL-m..V1/LAMTL-mipi转LVDS模块-HW_documents-V1.1/LAMTL-TC358775XBG-DSI-LVDS-timing.xls")
s = wb.sheet_by_name("Code")
for r in range(min(s.nrows, 120)):
    v = s.cell_value(r, 0)
    if str(v).strip():
        print(r, "|", str(v)[:110])
EOF
