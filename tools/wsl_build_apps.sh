#!/bin/bash
O="/mnt/d/Claude code/Case6_Astra/tools/_wslout"; mkdir -p "$O"
R='/mnt/d/Claude code/Case6_Astra/meta-dlsdk'
rsync -a --delete --delete-excluded \
  --exclude='*.repo_stale_*' --exclude='*.pre_selfheal' --exclude='*.orig' --exclude='*DANGEROUS*' \
  "$R/" /home/astra/sdk/meta-dlsdk/
cd /home/astra/sdk
set +e
source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1

echo "════ sherpa-onnx 的包产出在哪 ════"
grep -m1 "^PACKAGE_CLASSES" build-sl1680/conf/local.conf | sed 's/^/  /'
find build-sl1680/tmp/deploy -name "sherpa-onnx*" 2>/dev/null | head -n 6 | sed 's|.*/deploy/|  deploy/|'

echo
echo "════ 构建 astra-voice(真正的考验：链接刚编出来的 sherpa) ════"
bitbake astra-voice > "$O/av.log" 2>&1
RC1=$?
[ $RC1 -eq 0 ] && echo "  ✅✅ astra-voice 全绿" || { echo "  ❌ rc=$RC1"; grep -E "^ERROR" "$O/av.log" | head -n 6 | sed 's/^/    /'; }

W1=build-sl1680/tmp/work/cortexa73-poky-linux/astra-voice/1.0
if [ $RC1 -ne 0 ]; then
  L=$(grep "Logfile of failure stored in:" "$O/av.log" | tail -n 1 | sed 's/.*stored in: //')
  [ -f "$L" ] && { echo "    --- 错误详情 ---"; grep -E "error:|Error|No such file|undefined reference" "$L" | head -n 10 | sed 's/^/      /'; }
else
  echo "  产出:"
  ls -l $W1/image/usr/bin/astra_voice 2>/dev/null | awk '{printf "    %10s  %s\n",$5,$9}'
  echo "  NEEDED:"
  readelf -d $W1/image/usr/bin/astra_voice 2>/dev/null | grep NEEDED | sed 's/.*\[\(.*\)\]/    \1/'
  echo "  装了哪些文件:"
  find $W1/image -type f 2>/dev/null | sed "s|$W1/image|    |" | head -n 20
fi

echo
echo "════ 构建 dl-face ════"
bitbake dl-face > "$O/df.log" 2>&1
RC2=$?
[ $RC2 -eq 0 ] && echo "  ✅✅ dl-face 全绿" || { echo "  ❌ rc=$RC2"; grep -E "^ERROR" "$O/df.log" | head -n 6 | sed 's/^/    /'; }
W2=build-sl1680/tmp/work/cortexa73-poky-linux/dl-face/1.0
if [ $RC2 -eq 0 ]; then
  ls -l $W2/image/usr/bin/dl_face 2>/dev/null | awk '{printf "    %10s  %s\n",$5,$9}'
  readelf -d $W2/image/usr/bin/dl_face 2>/dev/null | grep NEEDED | sed 's/.*\[\(.*\)\]/    \1/'
else
  L=$(grep "Logfile of failure stored in:" "$O/df.log" | tail -n 1 | sed 's/.*stored in: //')
  [ -f "$L" ] && { echo "    --- 错误详情 ---"; grep -E "error:|Error|No such file|undefined reference" "$L" | head -n 10 | sed 's/^/      /'; }
fi
