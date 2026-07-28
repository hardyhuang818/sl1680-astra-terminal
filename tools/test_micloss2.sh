#!/bin/sh
set -u
# 用【整设备】unbind/bind 模拟拔插 —— 这才和真拔线等价
# (上次用接口级 unbind/bind，会把 ALSA 卡留在"有卡对象但无PCM流"的半死状态，真拔线不会)
setsid sh -c "sleep 120; echo 1-1.3 > /sys/bus/usb/drivers/usb/bind 2>/dev/null" >/dev/null 2>&1 &
echo "已挂 120 秒兜底重绑"

echo
echo "════ 1. 停服务 + 拔麦克风(整设备) ════"
systemctl stop astra-voice; systemctl stop vision-wake
sleep 1
R0=$(systemctl show -p NRestarts --value astra-voice)
echo "1-1.3" > /sys/bus/usb/drivers/usb/unbind 2>/dev/null
sleep 3
echo "  C920 卡: $([ -d /proc/asound/C920 ] && echo 还在 || echo 没了 ✓)"
echo "  采集节点 pcmC0D0c: $([ -e /dev/snd/pcmC0D0c ] && echo 还在 || echo 没了 ✓)"

echo
echo "════ 2. 麦克风不在时启动 —— 应安静等待 ════"
systemctl start astra-voice &
sleep 16
echo "  状态       = $(systemctl is-active astra-voice)   (期望 activating)"
echo "  加载模型   = $(journalctl -u astra-voice --no-pager -o cat --since '-25 seconds' 2>/dev/null | grep -c '加载模型') 次   (期望 0)"
echo "  NRestarts  = $(systemctl show -p NRestarts --value astra-voice)   (期望 $R0 不变)"
echo "  打不开报错 = $(journalctl -u astra-voice --no-pager -o cat --since '-25 seconds' 2>/dev/null | grep -c '打不开') 次   (期望 0)"
journalctl -u astra-voice --no-pager -o cat -n 6 2>/dev/null | grep "wait-mic" | tail -n 1 | sed 's/^/    /'

echo
echo "════ 3. 插回来 —— 应自动继续，不重启 ════"
echo "1-1.3" > /sys/bus/usb/drivers/usb/bind 2>/dev/null
sleep 32
echo "  状态       = $(systemctl is-active astra-voice)   (期望 active)"
echo "  NRestarts  = $(systemctl show -p NRestarts --value astra-voice)   (期望仍是 $R0)"
journalctl -u astra-voice --no-pager -o cat -n 12 2>/dev/null | grep -E "wait-mic|模型就绪|开始监听|打不开" | tail -n 4 | sed 's/^/    /'

echo
echo "════ 4. 收尾 ════"
systemctl start vision-wake
sleep 6
for s in astra-voice astra-translate dl-face vision-wake; do
  printf "  %-18s %s\n" "$s" "$(systemctl is-active $s)"
done
rm -f /tmp/mictest.wav
arecord -D plughw:CARD=C920,DEV=0 -f S16_LE -r 16000 -c 1 -d 1 /tmp/mictest.wav 2>/dev/null
[ -s /tmp/mictest.wav ] && echo "  麦克风实录: ✓ $(stat -c %s /tmp/mictest.wav) 字节" || echo "  麦克风实录: ✗"
