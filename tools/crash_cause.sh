#!/bin/sh
echo "════ 每次 FAILURE 之前程序最后说了什么 ════"
for t in 13:16:49 13:17:13 13:17:39 13:39:19 13:39:48 13:40:17; do
  echo "--- 退出于 $t"
  journalctl -u astra-voice --no-pager -o cat -b --until "$t" 2>/dev/null | tail -n 4 | sed 's/^/    /'
done

echo
echo "════ 完整搜一遍错误关键词(放宽) ════"
journalctl -u astra-voice --no-pager -o cat -b 2>/dev/null \
  | grep -viE "^\[你 |^\[机器|^\[存 |^\[唤醒|^\[跳过" \
  | sort | uniq -c | sort -rn | head -n 20 | sed 's/^/  /'

echo
echo "════ 同期 dmesg 里的 USB/音频事件 ════"
dmesg -T 2>/dev/null | grep -iE "usb|snd|audio|xhci" | tail -n 15 | sed 's/^/  /'
