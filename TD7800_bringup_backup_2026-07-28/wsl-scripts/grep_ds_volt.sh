#!/bin/bash
T=/tmp/ds.txt
if [ ! -f $T ]; then
  pdftotext -layout "/mnt/d/Claude code/Case6_Astra/MIPI to LVDS board-1/LAMTL-m..V1/LAMTL-mipi转LVDS模块-HW_documents-V1.1/LAMTL-TC358775XBG-datasheet.pdf" $T
fi
echo "════ 绝对最大值 ════"
grep -n -A12 -i "absolute maximum" $T | head -n 30
echo
echo "════ 1.8V 供电工作范围 ════"
grep -n -B2 -A3 "1\.8.*V\|VDD.*18\|1\.65\|1\.95" $T | grep -iE "vdd|supply|1\.[6789]|2\.[0-9]" | head -n 20
