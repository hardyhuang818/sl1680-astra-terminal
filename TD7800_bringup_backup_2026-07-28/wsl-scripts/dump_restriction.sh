#!/bin/bash
python3 - <<'EOF'
import xlrd
wb = xlrd.open_workbook("/mnt/d/Claude code/Case6_Astra/MIPI to LVDS board-1/LAMTL-m..V1/LAMTL-mipi转LVDS模块-HW_documents-V1.1/LAMTL-TC358775XBG-DSI-LVDS-timing.xls")
for name in ("Restriction", "How to use", "Host Access"):
    s = wb.sheet_by_name(name)
    print("═" * 10, name, s.nrows, "x", s.ncols, "═" * 10)
    for r in range(s.nrows):
        row = []
        for c in range(s.ncols):
            v = str(s.cell_value(r, c)).strip()
            if v and v != "0.0":
                row.append("[%d,%d]%s" % (r, c, v[:70]))
        if row:
            print(" | ".join(row)[:240])
EOF
