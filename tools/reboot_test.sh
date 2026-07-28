#!/bin/sh
echo "════ 重启前 ════"
echo "  C920 在不在: $(arecord -l 2>/dev/null | grep -c C920) (1=在)"
systemctl start astra-voice
sleep 25
echo "  astra-voice: $(systemctl is-active astra-voice)"
journalctl -u astra-voice --no-pager -o cat -n 5 2>/dev/null | tail -n 3 | sed 's/^/    /'
echo
echo "  重启前三块屏:"
journalctl -u dl-face --no-pager -o cat -b 2>/dev/null | grep "屏点亮" | tail -n 4 | sed 's/^/    /'
echo "  音量: $(amixer -c dolphinasoc sget AstraVolume 2>/dev/null | grep -oE '\[[0-9]+%\]' | head -n 1)"
echo
echo "════ 现在重启 ════"
sync
(sleep 2; reboot) &
echo "  reboot 已发出"
