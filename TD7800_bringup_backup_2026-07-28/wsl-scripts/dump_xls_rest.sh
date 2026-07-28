#!/bin/bash
python3 - <<'EOF'
import xlrd
wb = xlrd.open_workbook("/mnt/d/Claude code/Case6_Astra/MIPI to LVDS board-1/LAMTL-m..V1/LAMTL-mipi转LVDS模块-HW_documents-V1.1/LAMTL-TC358775XBG-DSI-LVDS-timing.xls")
s = wb.sheet_by_name("Code")
print("==== Code rows 119-270 ====")
for r in range(119, s.nrows):
    v = s.cell_value(r, 0)
    if str(v).strip():
        print(r, "|", str(v)[:110])
EOF
