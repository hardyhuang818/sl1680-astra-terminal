#!/bin/sh
echo "════ astra-voice 服务状态 ════"
systemctl status astra-voice --no-pager -n 0 2>/dev/null | head -n 6 | sed 's/^/  /'
echo "  NRestarts=$(systemctl show -p NRestarts --value astra-voice)"
echo "  Result=$(systemctl show -p Result --value astra-voice)"
echo "  ExecMainStatus=$(systemctl show -p ExecMainStatus --value astra-voice)"
echo "  ExecMainCode=$(systemctl show -p ExecMainCode --value astra-voice)"

echo
echo "════ 它是怎么停的(最后 25 行) ════"
journalctl -u astra-voice --no-pager -o short-iso -n 25 2>/dev/null | tail -n 20 | sed 's/^/  /'

echo
echo "════ 有没有 OOM ════"
dmesg 2>/dev/null | grep -iE "out of memory|oom-kill|killed process" | tail -n 5 | sed 's/^/  /'
echo "  (空 = 没有 OOM)"
echo "  内存: $(free -m | awk '/Mem:/{printf "已用 %sMB / 共 %sMB, 可用 %sMB",$3,$2,$7}')"

echo
echo "════ 麦克风被谁占着(它起不来的常见原因) ════"
for d in /dev/snd/pcm*c /dev/snd/controlC*; do
  h=$(fuser "$d" 2>/dev/null)
  [ -n "$h" ] && { printf "  %s -> " "$d"; for p in $h; do cat /proc/$p/comm 2>/dev/null | tr '\n' ' '; done; echo; }
done
echo "  C920 采集设备:"
arecord -l 2>/dev/null | grep -i c920 | sed 's/^/    /'
