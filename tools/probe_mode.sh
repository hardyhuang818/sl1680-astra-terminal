#!/bin/sh
echo "=== /usr/bin/astra_mode.sh 存在? ==="
ls -l /usr/bin/astra_mode.sh 2>/dev/null || echo "  不存在"
echo
echo "=== astra-mode 到底在干嘛(它连的 192.168.5.166 是已下线的PC) ==="
systemctl status astra-mode --no-pager -n 0 2>/dev/null | grep -E "Active|Main PID"
journalctl -u astra-mode --no-pager -n 8 -o cat 2>/dev/null | tail -n 6
echo
echo "=== silent.wav ==="
ls -l /home/voice/silent.wav 2>/dev/null || echo "  不存在"
echo
echo "=== softvol 控件是否要先开一次PCM才出现 ==="
amixer -c dolphinasoc scontrols 2>/dev/null | sed 's/^/  /'
