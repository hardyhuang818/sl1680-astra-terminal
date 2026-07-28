#!/bin/bash
W=/home/astra/sdk/build-sl1680/tmp/work/cortexa73-poky-linux/sherpa-onnx/1.13.4
L=$(ls -t $W/temp/log.do_package.[0-9]* 2>/dev/null | head -n 1)
echo "日志: ${L##*/}"
echo
echo "════ 装了但没打包的文件 ════"
grep -A60 "installed but not shipped" "$L" 2>/dev/null | grep -E "^\s+/" | sed 's/^/  /' | head -n 40
echo
echo "════ 汇总：按目录归类 ════"
grep -A200 "installed but not shipped" "$L" 2>/dev/null | grep -oE "^\s+/[a-z/]*" | sed 's/^ *//' | sed 's|\(/usr/[a-z]*/[a-z0-9._-]*\).*|\1|' | sort | uniq -c | sort -rn | head -n 15 | sed 's/^/  /'
echo
echo "════ image/ 里的完整目录树(顶层) ════"
find $W/image -maxdepth 3 -type d 2>/dev/null | sed "s|$W/image||" | grep -v "^$" | sort | sed 's/^/  /' | head -n 20
echo
echo "════ image/usr/share 下有什么(espeak-ng 数据?) ════"
ls $W/image/usr/share/ 2>/dev/null | sed 's/^/  /'
du -sh $W/image/usr/share/* 2>/dev/null | sed 's/^/  /'
