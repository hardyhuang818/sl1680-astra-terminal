#!/bin/bash
# 绝对路径，不受 oe-init-build-env 切目录影响
B=/home/astra/sdk/build-sl1680
W=$B/tmp/work/cortexa73-poky-linux

echo "════ astra_voice 产物 ════"
f=$W/astra-voice/1.0/image/usr/bin/astra_voice
if [ -f "$f" ]; then
  ls -l "$f" | awk '{printf "  %10s  %s\n",$5,$9}'
  file "$f" | sed 's|.*: |  |'
  echo "  NEEDED:"
  readelf -d "$f" | grep NEEDED | sed 's/.*\[\(.*\)\]/    \1/'
else
  echo "  ❌ 不存在"
fi

echo
echo "════ astra-voice 包装了哪些文件 ════"
find $W/astra-voice/1.0/image -type f 2>/dev/null | sed "s|$W/astra-voice/1.0/image|  |" | sort

echo
echo "════ dl_face 产物 ════"
f=$W/dl-face/1.0/image/usr/bin/dl_face
if [ -f "$f" ]; then
  ls -l "$f" | awk '{printf "  %10s  %s\n",$5,$9}'
  file "$f" | sed 's|.*: |  |'
  readelf -d "$f" | grep NEEDED | sed 's/.*\[\(.*\)\]/    /'
else
  echo "  ❌ 不存在"
fi

echo
echo "════ 打出来的包(ipk/deb/rpm) ════"
grep -m1 "^PACKAGE_CLASSES" $B/conf/local.conf | sed 's/^/  /'
for n in sherpa-onnx astra-voice dl-face; do
  echo "  --- $n"
  find $B/tmp/deploy -name "${n}[-_]*" -type f 2>/dev/null | grep -vE "\.spdx|licenses" | head -n 4 | while read p; do
    printf "    %9s  %s\n" "$(stat -c %s "$p")" "$(basename "$p")"
  done
done
