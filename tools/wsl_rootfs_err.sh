#!/bin/bash
O="/mnt/d/Claude code/Case6_Astra/tools/_wslout"
B=/home/astra/sdk/build-sl1680
echo "════ bitbake 输出里的 ERROR ════"
grep -E "^ERROR" "$O/image.log" 2>/dev/null | head -n 12 | sed 's/^/  /'
echo
L=$(grep "Logfile of failure stored in:" "$O/image.log" 2>/dev/null | tail -n 1 | sed 's/.*stored in: //')
echo "════ 失败日志: ${L##*/} ════"
if [ -f "$L" ]; then
  echo "── 关键行 ──"
  grep -iE "error|cannot|unable|conflict|unmet|not found|No such|abort|Assertion" "$L" | head -n 25 | sed 's/^/  /'
  echo
  echo "── 尾部 30 行 ──"
  tail -n 30 "$L" | cut -c1-220 | sed 's/^/  /'
else
  echo "  找不到日志，列出 rootfs 相关日志:"
  ls -t $B/tmp/work/sl1680-poky-linux/astra-media/*/temp/log.do_rootfs* 2>/dev/null | head -n 3 | sed 's|.*/|  |'
  L2=$(ls -t $B/tmp/work/sl1680-poky-linux/astra-media/*/temp/log.do_rootfs.[0-9]* 2>/dev/null | head -n 1)
  [ -f "$L2" ] && { echo "  用 ${L2##*/}:"; tail -n 30 "$L2" | cut -c1-220 | sed 's/^/    /'; }
fi
