#!/bin/sh
set -u
echo "════ 整设备重新枚举 1-1.3 ════"
systemctl stop astra-voice 2>/dev/null
systemctl stop vision-wake 2>/dev/null
sleep 1

echo "1-1.3" > /sys/bus/usb/drivers/usb/unbind 2>/dev/null
echo "  unbind 完成，等 4 秒"
sleep 4
echo "1-1.3" > /sys/bus/usb/drivers/usb/bind 2>/dev/null
echo "  bind 完成，等 8 秒让枚举稳定"
sleep 8

echo
echo "════ 硬判据：PCM 流回来了吗 ════"
echo "  /proc/asound/pcm 里 card0 的条目:"
grep "^00-" /proc/asound/pcm 2>/dev/null | sed 's/^/    /' || echo "    (无)"
echo "  采集节点: $(ls /dev/snd/pcmC*D0c 2>/dev/null | tr '\n' ' ')"
echo "  arecord 看得到 C920: $(arecord -l 2>/dev/null | grep -c C920)"

echo
echo "════ 最硬判据：真录一秒 ════"
rm -f /tmp/mictest.wav
arecord -D plughw:CARD=C920,DEV=0 -f S16_LE -r 16000 -c 1 -d 1 /tmp/mictest.wav 2>&1 | head -n 2 | sed 's/^/  /'
if [ -s /tmp/mictest.wav ]; then
  echo "  ✓ 录到 $(stat -c %s /tmp/mictest.wav) 字节"
  python3 - <<'PY'
import wave,struct,math
w=wave.open("/tmp/mictest.wav","rb"); d=w.readframes(w.getnframes()); w.close()
s=struct.unpack("<%dh"%(len(d)//2), d)
print("  RMS=%.0f  峰值=%d  (RMS>0 说明真有信号)" % (math.sqrt(sum(x*x for x in s)/len(s)), max(abs(x) for x in s)))
PY
else
  echo "  ✗ 仍然录不到"
fi

echo
echo "════ wait_mic 现在怎么判 ════"
T0=$(date +%s); /usr/bin/astra_wait_mic.sh C920 15; echo "  退出码=$? 耗时=$(( $(date +%s) - T0 ))s (麦好的话应约 2s)"

echo
echo "════ 恢复服务 ════"
systemctl start vision-wake
systemctl start astra-voice
sleep 26
for s in astra-voice astra-translate dl-face vision-wake; do
  printf "  %-18s %s\n" "$s" "$(systemctl is-active $s)"
done
echo "  NRestarts=$(systemctl show -p NRestarts --value astra-voice)"
journalctl -u astra-voice --no-pager -o cat -n 8 2>/dev/null | grep -E "wait-mic|模型就绪|开始监听|打不开" | tail -n 3 | sed 's/^/    /'
