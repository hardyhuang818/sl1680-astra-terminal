#!/bin/bash
python3 - <<'EOF'
import xlrd
wb = xlrd.open_workbook("/mnt/d/Claude code/Case6_Astra/MIPI to LVDS board-1/LAMTL-m..V1/LAMTL-mipi转LVDS模块-HW_documents-V1.1/LAMTL-TC358775XBG-DSI-LVDS-timing.xls")
s = wb.sheet_by_name("Timing Parameters_SYNC_EVENT")
print("==== SYNC_EVENT 非空单元格 (r,c,值) ====")
for r in range(s.nrows):
    for c in range(s.ncols):
        v = s.cell_value(r, c)
        t = str(v).strip()
        if t and t != "0.0":
            print(f"[{r},{c}] {t[:60]}")
EOF
