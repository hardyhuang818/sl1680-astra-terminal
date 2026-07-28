#!/bin/sh
echo "=== /proc/asound 里的卡 ==="
ls /proc/asound/ | sed 's/^/  /'
echo
echo "=== /proc/asound/cards ==="
cat /proc/asound/cards | sed 's/^/  /'
echo
echo "=== 判断法 A: 目录存在? ==="
[ -d /proc/asound/C920 ] && echo "  [ -d /proc/asound/C920 ] = 真 ✓" || echo "  假"
echo
echo "=== 判断法 B: 采集设备存在? ==="
[ -e /dev/snd/pcmC2D0c ] && echo "  pcmC2D0c 存在(但卡号会变，不可靠)" || echo "  不存在"
echo
echo "=== 判断法 C: arecord -l ==="
arecord -l 2>/dev/null | grep -i c920 | sed 's/^/  /'
echo
echo "=== 现有 astra-voice.service 的 ExecStartPre ==="
grep -n "ExecStartPre" /etc/systemd/system/astra-voice.service | sed 's/^/  /'
echo
echo "=== systemd 启动限流参数(默认 5次/10秒) ==="
systemctl show astra-voice -p StartLimitBurst -p StartLimitIntervalUSec -p RestartSec | sed 's/^/  /'
