#!/bin/bash
O="/mnt/d/Claude code/Case6_Astra/tools/_wslout"
echo "=== 构建结果 ==="
tail -n 5 "$O/av_build.log" 2>/dev/null
grep -cE "^ERROR" "$O/av_build.log" 2>/dev/null
echo
echo "=== 找 astra_voice 产物 ==="
find /home/astra/sdk/build-sl1680/tmp/work -path "*astra-voice*" -name "astra_voice" -type f 2>/dev/null | head -n 5
echo
echo "=== deb 包 ==="
find /home/astra/sdk/build-sl1680/tmp/deploy/deb -name "astra-voice*" -newermt "-40 minutes" 2>/dev/null | head -n 3
