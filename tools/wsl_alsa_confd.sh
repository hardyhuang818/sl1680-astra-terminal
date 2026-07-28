#!/bin/bash
cd /home/astra/sdk
source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1
B=/home/astra/sdk/build-sl1680

echo "════ alsa-lib 的 alsa.conf 有没有包含 conf.d 目录 ════"
f=$(find $B/tmp/work/cortexa73-poky-linux/alsa-lib/*/image/usr/share/alsa/alsa.conf 2>/dev/null | head -n 1)
[ -z "$f" ] && f=$(find $B/tmp/sysroots-components -path "*share/alsa/alsa.conf" 2>/dev/null | head -n 1)
if [ -n "$f" ]; then
  echo "  文件: $f"
  tail -n 12 "$f" | sed 's/^/    /'
  echo "  --- 是否有 conf.d 包含指令 ---"
  grep -nE "conf\.d|</etc/alsa" "$f" | sed 's/^/    /'
else
  echo "  没找到 alsa.conf，从板子上查更快"
fi

echo
echo "════ alsa-state 的 asound.conf 长什么样(是不是占位文件) ════"
oe-pkgdata-util find-path "/etc/asound.conf" 2>/dev/null | sed 's/^/  /'
d=$(find $B/tmp/work/*/alsa-state/*/image/etc/asound.conf 2>/dev/null | head -n 1)
if [ -n "$d" ]; then
  echo "  alsa-state 版内容($(stat -c %s $d) 字节):"
  cat "$d" | sed 's/^/    /'
else
  echo "  (alsa-state 未构建，从 deb 里看)"
  p=$(find $B/tmp/deploy/deb -name "alsa-state_*.deb" | head -n 1)
  [ -n "$p" ] && { echo "  $p"; dpkg -c "$p" | grep asound | sed 's/^/    /'; }
fi
