#!/bin/bash
T=/tmp/td.txt
echo "════ 章节定位 ════"
grep -n "Fault Detection Function in the LVDS\|Fail Detect Function\|FAIL_DET" $T | head -12
echo
L=$(grep -n "Fault Detection Function in the LVDS Interface" $T | sed -n 2p | cut -d: -f1)
[ -z "$L" ] && L=$(grep -n "Fault Detection Function in the LVDS Interface" $T | head -1 | cut -d: -f1)
echo "════ 22.11 正文 (line $L) ════"
sed -n "${L},$((L+60))p" $T
