#!/bin/bash
D=/home/astra/sdk/build-sl1680/tmp/deploy/images/sl1680
IMG=$(ls -t $D/astra-media-sl1680.rootfs-*.ext4 2>/dev/null | head -n 1)
echo "════ wqy-zenhei 字体到底装在哪 ════"
cd /home/astra/sdk && source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1
oe-pkgdata-util find-path "*wqy-zenhei*" 2>/dev/null | sed 's/^/  /'
echo "  镜像里核对:"
for p in /usr/share/fonts/truetype/wqy-zenhei.ttc /usr/share/fonts/truetype/wqy-zenhei.ttf /usr/share/fonts/wqy-zenhei/wqy-zenhei.ttc; do
  s=$(debugfs -R "stat $p" "$IMG" 2>/dev/null | grep -m1 -oE "Size: [0-9]+" | cut -d' ' -f2)
  [ -n "$s" ] && printf "    ✓ %s  %s 字节\n" "$p" "$s"
done

echo
echo "════ ★ 镜像里哪些服务会开机自启 ════"
debugfs -R "ls /etc/systemd/system/multi-user.target.wants" "$IMG" 2>/dev/null | tr ' ' '\n' | grep -E "service|timer" | sed 's/^/  /'
echo
echo "════ 对照板子上实际 enable 的(2026-07-23 导出) ════"
echo "    astra-voice      enabled"
echo "    astra-translate  enabled"
echo "    dl-face          enabled"
echo "    vision-wake      enabled   ← 镜像里有吗?"
echo "    astra-cleanup.timer enabled ← 镜像里有吗?"
echo "    astra-mode       disabled  (故意的，不能自启)"
