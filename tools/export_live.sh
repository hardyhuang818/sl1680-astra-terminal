#!/bin/sh
# 导出板端【实际运行】的全部配置与脚本，供回灌仓库
set -u
D=/tmp/live_export
rm -rf $D; mkdir -p $D
echo "=== 导出板端实际文件 ==="
for f in /etc/systemd/system/astra-voice.service \
         /etc/systemd/system/astra-mode.service \
         /etc/systemd/system/astra-translate.service \
         /etc/systemd/system/dl-face.service \
         /etc/systemd/system/vision-wake.service \
         /etc/asound.conf \
         /usr/bin/vision_wake.sh \
         /usr/bin/astra_setvol.sh \
         /home/voice/astra_llm.py \
         /home/voice/astra_translate.py ; do
  if [ -f "$f" ]; then
    cp "$f" "$D/$(basename $f)" && echo "  $f"
  else
    echo "  !! 不存在: $f"
  fi
done

echo
echo "=== 生成 sha256 manifest ==="
{
  echo "# 板端实际运行文件 manifest"
  echo "# 导出时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "# 内核: $(uname -r)"
  echo ""
  printf "%-64s  %s\n" "SHA256" "板端路径"
  for f in /etc/systemd/system/astra-voice.service \
           /etc/systemd/system/astra-mode.service \
           /etc/systemd/system/astra-translate.service \
           /etc/systemd/system/dl-face.service \
           /etc/systemd/system/vision-wake.service \
           /etc/asound.conf \
           /usr/bin/vision_wake.sh \
           /usr/bin/astra_setvol.sh \
           /usr/bin/dl_face \
           /home/voice/astra_llm.py \
           /home/voice/astra_translate.py ; do
    [ -f "$f" ] && printf "%s  %s\n" "$(sha256sum $f | cut -d' ' -f1)" "$f"
  done
  echo ""
  echo "# systemd enable 状态"
  for s in astra-voice astra-mode astra-translate dl-face vision-wake astra-xiaozhi; do
    printf "%-18s active=%-9s enabled=%s\n" "$s" "$(systemctl is-active $s 2>/dev/null)" "$(systemctl is-enabled $s 2>/dev/null)"
  done
} > $D/MANIFEST.txt
cat $D/MANIFEST.txt

echo
echo "=== 打包 ==="
cd /tmp && tar czf live_export.tar.gz live_export
ls -l /tmp/live_export.tar.gz
