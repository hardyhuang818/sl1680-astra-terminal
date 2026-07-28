#!/bin/sh
evtest /dev/input/event2 > /tmp/ev.log 2>&1 &
EP=$!
sleep 15
kill $EP 2>/dev/null
echo "=== 设备信息 ==="
sed -n '1,20p' /tmp/ev.log
echo
echo "=== 事件流(最后40行) ==="
tail -n 40 /tmp/ev.log
echo
N=$(grep -c "ABS_MT_POSITION" /tmp/ev.log)
echo "坐标报点行数: $N"
