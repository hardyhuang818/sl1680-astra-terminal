#!/bin/sh
echo "════ 板端最终状态 ════"
echo "  开机: $(uptime | sed 's/.*up //; s/,.*load.*//')   负载: $(uptime | sed 's/.*load average: //')"
for s in astra-voice astra-translate dl-face vision-wake astra-mode astra-xiaozhi; do
  printf "  %-18s active=%-9s enabled=%s\n" "$s" "$(systemctl is-active $s)" "$(systemctl is-enabled $s 2>/dev/null)"
done
echo "  astra-voice NRestarts=$(systemctl show -p NRestarts --value astra-voice)"
echo "  dl-face     NRestarts=$(systemctl show -p NRestarts --value dl-face)"
echo "  音量: $(amixer -c dolphinasoc sget AstraVolume 2>/dev/null | grep -oE '\[[0-9]+%\]' | head -n 1)"
echo "  屏幕: $(journalctl -u dl-face --no-pager -o cat -b 2>/dev/null | grep -c '屏点亮') 块点亮"
echo "  C920: 音频 $(arecord -l 2>/dev/null | grep -c C920) / 视频 $(ls /dev/v4l/by-id/ 2>/dev/null | grep -c C920)"
echo
echo "════ 本次新增文件的 sha256(写进清单) ════"
for f in /usr/bin/astra_wait_mic.sh /etc/systemd/system/astra-voice.service; do
  printf "  %s  %s\n" "$(sha256sum $f | cut -d' ' -f1)" "$f"
done
echo
echo "════ ExecStartPre 顺序确认 ════"
systemctl show astra-voice -p ExecStartPre --value | tr ';' '\n' | grep -o 'path=[^ ]*' | sed 's/path=/  /'
