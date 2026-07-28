#!/bin/sh
echo "=== 开机多久了 ==="
uptime | sed 's/^/  /'
echo
echo "=== dl-face ==="
echo "  状态: $(systemctl is-active dl-face)   NRestarts=$(systemctl show -p NRestarts --value dl-face)"
journalctl -u dl-face --no-pager -n 40 -o cat 2>/dev/null | grep -E "注册|发现|屏点亮|切换角色" | tail -n 5
echo
echo "=== 屏幕角色 ==="
cat /tmp/astra_screen_mode.txt 2>/dev/null | sed 's/^/  /'
echo
echo "=== DL7400 USB 在不在 ==="
lsusb 2>/dev/null | grep -i "17e9" | sed 's/^/  /'
echo
echo "=== 五个服务 ==="
for s in astra-voice astra-mode astra-translate dl-face vision-wake; do
  printf "  %-18s %s\n" "$s" "$(systemctl is-active $s)"
done
echo
echo "=== C920 被谁占 ==="
for d in /dev/video*; do
  n=$(cat /sys/class/video4linux/$(basename "$d")/name 2>/dev/null)
  case "$n" in *C920*|*Webcam*)
    h=$(fuser "$d" 2>/dev/null)
    [ -n "$h" ] && { printf "  %s -> " "$d"; for p in $h; do cat /proc/$p/comm 2>/dev/null | tr '\n' ' '; done; echo; }
  ;; esac
done
