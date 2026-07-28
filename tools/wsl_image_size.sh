#!/bin/bash
O="/mnt/d/Claude code/Case6_Astra/tools/_wslout"; mkdir -p "$O"
cd /home/astra/sdk
set +e
source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1
echo "════ 完整镜像要跑多少任务(dry-run 估算规模) ════"
timeout 900 bitbake -n astra-media > "$O/imn.log" 2>&1
RC=$?
if [ $RC -eq 0 ]; then
  grep "Tasks Summary" "$O/imn.log" | tail -n 1 | sed 's/^/  /'
  echo
  echo "  解读: 'didn't need to be rerun' 越多 = sstate 命中越多 = 越快"
elif [ $RC -eq 124 ]; then
  echo "  ⚠️ dry-run 本身超过 15 分钟(依赖图太大)"
else
  echo "  ❌ rc=$RC"
  grep -E "^ERROR|Nothing (PROVIDES|RPROVIDES)" "$O/imn.log" | head -n 10 | sed 's/^/  /'
fi
echo
echo "════ sstate 缓存规模 ════"
du -sh /home/astra/sdk/build-sl2619/sstate-cache 2>/dev/null | sed 's/^/  /'
echo "  磁盘剩余:"
df -h /home/astra | tail -n 1 | awk '{printf "    可用 %s / 共 %s (已用 %s)\n",$4,$2,$5}'
