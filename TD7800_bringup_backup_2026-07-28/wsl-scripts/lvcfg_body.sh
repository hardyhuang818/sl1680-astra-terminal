#!/bin/bash
T=/tmp/ds.txt
L=$(grep -n "LVDS Configuration Register (LVCFG)" $T | tail -1 | cut -d: -f1)
echo "line $L"
sed -n "${L},$((L+45))p" $T
