#!/bin/bash
T=/tmp/td.txt
echo "════ B1h LVDS IF Setting 正文 (9372起) ════"
sed -n "9372,9470p" $T
echo
echo "════ C0h Display Timing 正文头部 (10508起, 前60行) ════"
sed -n "10508,10568p" $T
