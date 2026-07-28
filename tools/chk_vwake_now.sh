#!/bin/sh
echo "=== 屏幕角色文件 ==="
cat /tmp/astra_screen_mode.txt 2>/dev/null | tr '\n' ' '; echo
echo
echo "=== 摄像头被谁占 ==="
for d in /dev/video*; do
  n=$(cat /sys/class/video4linux/$(basename "$d")/name 2>/dev/null)
  case "$n" in *C920*|*Webcam*)
    h=$(fuser "$d" 2>/dev/null)
    if [ -n "$h" ]; then
      printf "  %s (%s) -> " "$d" "$n"
      for p in $h; do cat /proc/$p/comm 2>/dev/null | tr '\n' ' '; done; echo
    fi
  ;; esac
done
echo
echo "=== vision-wake 为什么停的 ==="
systemctl status vision-wake --no-pager -n 0 2>/dev/null | head -n 4
journalctl -u vision-wake --no-pager -n 6 -o cat 2>/dev/null | tail -n 4
echo
echo "=== dl-face 角色切换记录 ==="
journalctl -u dl-face --no-pager -n 20 -o cat 2>/dev/null | grep "切换角色" | tail -n 3
echo
echo "=== 最近语音识别(看有没有误触发切屏) ==="
journalctl -u astra-voice --no-pager -n 40 -o cat 2>/dev/null | grep -E "^\[你|^\[机器" | tail -n 6
echo
echo "════ 复位: 两块屏都表情脸 + 恢复视觉唤醒 ════"
printf '0=face\n1=face\n' > /tmp/astra_screen_mode.txt
sleep 6
systemctl restart vision-wake
sleep 10
echo "角色: $(cat /tmp/astra_screen_mode.txt | tr '\n' ' ')"
echo "vision-wake: $(systemctl is-active vision-wake)"
echo "抓帧文件: $(ls /tmp/vw_*.jpg 2>/dev/null | wc -l) 个"
echo "音量: $(amixer -c dolphinasoc sget AstraVolume 2>/dev/null | grep -oE '\[[0-9]+%\]' | head -n 1)"
echo
for s in astra-voice astra-mode astra-translate dl-face vision-wake; do
  printf "  %-18s %s\n" "$s" "$(systemctl is-active $s)"
done
