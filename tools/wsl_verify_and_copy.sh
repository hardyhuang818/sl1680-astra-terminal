#!/bin/bash
set -u
S=/home/astra/sdk/build-sl1680/tmp/deploy/images/sl1680
IMG=$(ls -t $S/astra-media-sl1680.rootfs-*.ext4 2>/dev/null | head -n 1)

echo "════ 1. 验证两项修复(不过就不复制) ════"
# ⚠️ .timer 的软链在 timers.target.wants，不在 multi-user.target.wants —— 两个都要看。
#    第一版只查了 multi-user，把正常的 astra-cleanup.timer 误报成"缺失"。
W=$( { debugfs -R "ls /etc/systemd/system/multi-user.target.wants" "$IMG" 2>/dev/null
       debugfs -R "ls /etc/systemd/system/timers.target.wants"     "$IMG" 2>/dev/null
     } | tr ' ' '\n' | grep -E "service$|timer$")
OK=1
for s in astra-voice.service astra-translate.service dl-face.service vision-wake.service astra-cleanup.timer; do
  echo "$W" | grep -q "^$s$" && printf "  ✓ %-26s 自启\n" "$s" || { printf "  ❌ %-26s 缺失\n" "$s"; OK=0; }
done
for s in dl-clock.service astra-mode.service astra-xiaozhi.service; do
  echo "$W" | grep -q "^$s$" && { printf "  ❌ %-26s 不该自启却自启了\n" "$s"; OK=0; } || printf "  ✓ %-26s 未自启(正确)\n" "$s"
done
[ $OK -eq 0 ] && { echo; echo "  ⚠️ 验证未通过，不复制"; exit 1; }

echo
echo "  再抽查关键文件:"
for f in /usr/bin/astra_voice /usr/lib/libsherpa-onnx-c-api.so /usr/lib/libonnxruntime.so /etc/asound.conf /usr/bin/astra_wait_mic.sh; do
  s=$(debugfs -R "stat $f" "$IMG" 2>/dev/null | grep -m1 -oE "Size: [0-9]+" | cut -d' ' -f2)
  [ -n "$s" ] && printf "    ✓ %-40s %s\n" "$f" "$s" || { printf "    ❌ %s\n" "$f"; OK=0; }
done
[ $OK -eq 0 ] && exit 1

STAMP=$(basename "$IMG" | sed 's/.*rootfs-\([0-9]*\)\.ext4/\1/')
DST="/mnt/d/Claude code/Case6_Astra/flash_image_$STAMP"

echo
echo "════ 2. 复制到 $DST ════"
mkdir -p "$DST"
cp $S/SYNAIMG/* "$DST/" && echo "  SYNAIMG 复制完成"
cp $S/astra-media-sl1680.rootfs-$STAMP.manifest "$DST/packages.manifest" 2>/dev/null
sha256sum "$DST"/* 2>/dev/null | sed "s|$DST/||" > "$DST/SHA256SUMS.txt"

echo
echo "════ 3. 复制结果 ════"
ls -l "$DST" | awk 'NR>1{printf "  %12s  %s\n",$5,$9}'
echo "  合计: $(du -sh "$DST" | cut -f1)"
echo "  STAMP=$STAMP"
