#!/bin/bash
echo "════ bitbake 输出 ════"
grep -E "ERROR|WARNING|Exception|Parsing" /tmp/cf2.txt 2>/dev/null | head -n 12 | sed 's/^/  /'
echo
W=/home/astra/sdk/build-sl1680/tmp/work/cortexa73-poky-linux/sherpa-onnx/1.13.4
echo "════ 最新的 configure 日志 ════"
ls -t $W/temp/log.do_configure* 2>/dev/null | head -n 3 | sed 's|.*/|  |'
L=$(ls -t $W/temp/log.do_configure.* 2>/dev/null | head -n 1)
echo "  用: ${L##*/}   ($(stat -c %y "$L" 2>/dev/null | cut -d. -f1))"
echo
echo "  ── 尾部 25 行 ──"
tail -n 25 "$L" 2>/dev/null | cut -c1-200 | sed 's/^/    /'
