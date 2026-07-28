#!/bin/bash
T=/tmp/td.txt
echo "════ B1h LVDS IF Setting ════"
L=$(grep -n "LVDS IF Setting (B1h)" $T | tail -1 | cut -d: -f1)
sed -n "${L},$((L+58))p" $T
echo
echo "════ DDh LVDS Safety Function (前50行) ════"
L=$(grep -n "LVDS Safety Function (DDh)" $T | tail -1 | cut -d: -f1)
sed -n "${L},$((L+50))p" $T
