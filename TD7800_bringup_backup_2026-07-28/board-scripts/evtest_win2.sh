#!/bin/sh
B=$(grep synaptics_tcm /proc/interrupts | awk '{s=$2+$3+$4+$5} END {print s}')
echo "窗口开始前中断计数: $B"
evtest /dev/input/event2 > /tmp/ev2.log 2>&1 &
EP=$!
sleep 20
kill $EP 2>/dev/null
A=$(grep synaptics_tcm /proc/interrupts | awk '{s=$2+$3+$4+$5} END {print s}')
echo "窗口结束后中断计数: $A  (增量 $((A-B)))"
echo
echo "=== 实际触摸事件 (Event: time 行) ==="
grep "^Event: time" /tmp/ev2.log | head -n 30
N=$(grep -c "^Event: time" /tmp/ev2.log)
echo "事件总数: $N"
