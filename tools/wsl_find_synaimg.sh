#!/bin/bash
D=/home/astra/sdk/build-sl1680/tmp/deploy/images/sl1680
echo "════ 构建是否还在跑 ════"
pgrep -c bitbake >/dev/null 2>&1 && echo "  ⏳ bitbake 仍在运行" || echo "  ✅ 没有 bitbake 在跑"
echo
echo "════ deploy/images/sl1680 全部内容(按时间) ════"
ls -lt $D/ 2>/dev/null | head -n 30 | awk 'NR>1{printf "  %12s  %s  %s\n",$5,$6" "$7" "$8,$9}'
echo
echo "════ 有没有 SYNAIMG 目录结构 ════"
find $D -maxdepth 2 -type d 2>/dev/null | sed 's/^/  /'
ls $D/../SYNAIMG 2>/dev/null | head -n 5 | sed 's/^/    /'
echo
echo "════ emmc_image_list / part_list 在哪 ════"
find /home/astra/sdk/build-sl1680/tmp/deploy -name "emmc_*list" 2>/dev/null | head -n 4 | sed 's/^/  /'
find /home/astra/sdk -maxdepth 4 -name "emmc_image_list" 2>/dev/null | grep -v build-sl2619 | head -n 4 | sed 's/^/  /'
