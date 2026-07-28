#!/bin/sh
set -u
python3 - /tmp/astra_wait_mic.sh <<'PY'
import sys
p=sys.argv[1]; d=open(p,"rb").read()
if d[:3]==b"\xef\xbb\xbf": open(p,"wb").write(d[3:]); print("  剥掉 BOM")
PY
cp /tmp/astra_wait_mic.sh /usr/bin/astra_wait_mic.sh && chmod 0755 /usr/bin/astra_wait_mic.sh
grep -q "pcmC" /usr/bin/astra_wait_mic.sh && echo "  ✓ 新版已装(含采集节点检查)" || { echo "  ✗ 装失败"; exit 1; }

echo
echo "════ 静态自测 ════"
T0=$(date +%s); /usr/bin/astra_wait_mic.sh C920 10; echo "  麦在: 退出码=$? 耗时=$(( $(date +%s) - T0 ))s"
T0=$(date +%s); /usr/bin/astra_wait_mic.sh NOSUCHCARD 4 >/dev/null; echo "  卡不存在: 退出码=$? 耗时=$(( $(date +%s) - T0 ))s"

IF=$(ls /sys/bus/usb/drivers/snd-usb-audio/ 2>/dev/null | grep "^1-1\.3:" | head -n 1)
[ -z "$IF" ] && { echo "!! 找不到 C920 音频接口"; exit 1; }
setsid sh -c "sleep 100; echo '$IF' > /sys/bus/usb/drivers/snd-usb-audio/bind 2>/dev/null" >/dev/null 2>&1 &

echo
echo "════ 重跑掉线测试 ════"
systemctl stop astra-voice
sleep 1
R0=$(systemctl show -p NRestarts --value astra-voice)
echo "$IF" > /sys/bus/usb/drivers/snd-usb-audio/unbind
sleep 2
echo "  麦克风已拔 (/proc/asound/C920 存在? $([ -d /proc/asound/C920 ] && echo 是 || echo 否))"

systemctl start astra-voice &
sleep 14
echo "  状态=$(systemctl is-active astra-voice)  加载模型次数(近20s)=$(journalctl -u astra-voice --no-pager -o cat --since '-20 seconds' 2>/dev/null | grep -c '加载模型')  NRestarts=$(systemctl show -p NRestarts --value astra-voice)"

echo
echo "  ── 插回来 ──"
echo "$IF" > /sys/bus/usb/drivers/snd-usb-audio/bind
sleep 30
echo "  状态=$(systemctl is-active astra-voice)  NRestarts=$(systemctl show -p NRestarts --value astra-voice) (起始 $R0)"
echo "  日志:"
journalctl -u astra-voice --no-pager -o cat -n 14 2>/dev/null | grep -E "wait-mic|模型就绪|开始监听|打不开" | tail -n 4 | sed 's/^/    /'

echo
echo "════ 收尾确认 ════"
sleep 8
echo "  astra-voice: $(systemctl is-active astra-voice)"
echo "  C920: $(arecord -l 2>/dev/null | grep -c C920) (1=在)"
for s in astra-voice astra-translate dl-face vision-wake; do
  printf "  %-18s %s\n" "$s" "$(systemctl is-active $s)"
done
