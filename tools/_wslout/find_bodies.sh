#!/bin/bash
T=/tmp/td.txt
echo "════ 各节出现位置 ════"
for k in "LVDS IF Setting (B1h)" "LVDS Safety Function (DDh)" "Display Timing (C0h)" "Power/Display On/Off Sequence with FCS Pin = Low"; do
  echo "-- $k:"
  grep -n "$k" $T | head -4
done
echo
echo "════ SHUT/DISP 软件寄存器位 ════"
grep -n "SHUT" $T | grep -v -i "pin\|shutdown\|Shut down" | head -12
