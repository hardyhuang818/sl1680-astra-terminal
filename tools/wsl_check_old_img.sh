#!/bin/bash
S='/mnt/d/Claude code/Case6_Astra/delivery_sl1680/SYNAIMG'
T=/home/astra/_oldimg          # 用 WSL 原生盘，不用 /tmp
rm -rf $T; mkdir -p $T

echo "════ 源文件确认 ════"
ls -l $S/rootfs.subimg.gz $S/rootfs_s.subimg.0 2>&1 | awk '{printf "  %12s  %s\n",$5,$9}'
echo "  磁盘可用: $(df -h /home/astra | tail -1 | awk '{print $4}')"

echo
echo "════ 解压 rootfs.subimg.gz ════"
gzip -dc "$S/rootfs.subimg.gz" > $T/rootfs.img 2>$T/err.txt
echo "  rc=$?  大小=$(stat -c %s $T/rootfs.img 2>/dev/null)"
[ -s $T/err.txt ] && { echo "  错误:"; head -n 3 $T/err.txt | sed 's/^/    /'; }
file $T/rootfs.img 2>/dev/null | sed 's|.*: |  格式: |'

echo
echo "════ 如果不是 ext4，看看头 ════"
head -c 8 $T/rootfs.img 2>/dev/null | od -An -tx1 | sed 's/^/  /'
echo "  偏移 0x438 的 ext4 magic(应为 53ef):"
dd if=$T/rootfs.img bs=1 skip=1080 count=2 2>/dev/null | od -An -tx1 | sed 's/^/    /'

IMG=$T/rootfs.img
if [ -s "$IMG" ]; then
  echo
  echo "════ ★ 7/13 镜像里有没有语音终端 ════"
  for f in /usr/bin/astra_voice /usr/bin/dl_face /usr/lib/libdlsdk.so /home/voice /etc/asound.conf; do
    r=$(debugfs -R "stat $f" "$IMG" 2>&1 | grep -m1 -oE "Size: [0-9]+" | cut -d' ' -f2)
    [ -n "$r" ] && printf "  ✓ %-34s %s\n" "$f" "$r" || printf "  ✗ %-34s 不存在\n" "$f"
  done
  echo "  根目录抽查(证明 debugfs 读得动这个镜像):"
  debugfs -R "ls /" "$IMG" 2>/dev/null | tr ' ' '\n' | grep -vE "^$|^\.\.?$" | head -n 12 | tr '\n' ' ' | sed 's/^/    /'
  echo
fi
rm -rf $T
