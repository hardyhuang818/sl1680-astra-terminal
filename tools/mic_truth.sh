#!/bin/sh
echo "════ /proc/asound/cards ════"
cat /proc/asound/cards | sed 's/^/  /'
echo
echo "════ 各卡名字 -> 卡号 ════"
for d in /proc/asound/*; do
  n=$(basename "$d")
  case "$n" in card*|cards|devices|hwdep|modules|pcm|timers|version|oss|seq) continue;; esac
  echo "  $n -> $(readlink $d 2>/dev/null)"
done
echo
echo "════ arecord -l 全文 ════"
arecord -l 2>&1 | sed 's/^/  /'
echo
echo "════ /dev/snd ════"
ls /dev/snd/ | sed 's/^/  /'
echo
echo "════ /proc/asound/pcm ════"
cat /proc/asound/pcm 2>/dev/null | sed 's/^/  /'
echo
echo "════ 直接试开(最硬的判据) ════"
if arecord -D plughw:CARD=C920,DEV=0 -f S16_LE -r 16000 -c 1 -d 1 /tmp/mictest.wav 2>&1 | head -n 3 | sed 's/^/  /'; then :; fi
[ -s /tmp/mictest.wav ] && echo "  ✓ 录到了 $(stat -c %s /tmp/mictest.wav) 字节" || echo "  ✗ 没录到"
