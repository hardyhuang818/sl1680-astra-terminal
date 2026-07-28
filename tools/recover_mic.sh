#!/bin/sh
set -u
echo "════ 现状 ════"
echo "  USB 设备 1-1.3 还在吗: $([ -d /sys/bus/usb/devices/1-1.3 ] && echo 在 || echo 不在)"
[ -d /sys/bus/usb/devices/1-1.3 ] && echo "  product: $(cat /sys/bus/usb/devices/1-1.3/product 2>/dev/null)"
echo "  snd-usb-audio 下绑着的接口:"
ls /sys/bus/usb/drivers/snd-usb-audio/ 2>/dev/null | grep -E "^[0-9]" | sed 's/^/    /'
echo "  1-1.3 的所有接口:"
ls -d /sys/bus/usb/devices/1-1.3:* 2>/dev/null | sed 's|.*/|    |'
echo "  /proc/asound:"
ls /proc/asound/ | grep -vE "^(cards|devices|hwdep|modules|pcm|timers|version)$" | sed 's/^/    /'
echo "  /proc/asound/C920 是不是软链: $(readlink /proc/asound/C920 2>/dev/null || echo '(不是软链或不存在)')"

echo
echo "════ 尝试 1: 直接重绑音频接口 ════"
for i in /sys/bus/usb/devices/1-1.3:*; do
  n=$(basename "$i")
  if [ -f "$i/bInterfaceClass" ] && [ "$(cat $i/bInterfaceClass)" = "01" ]; then
    echo "  音频类接口 $n -> bind"
    echo "$n" > /sys/bus/usb/drivers/snd-usb-audio/bind 2>/dev/null
  fi
done
sleep 3
echo "  结果: C920 声卡 $([ -d /proc/asound/C920 ] && echo 回来了 ✓ || echo 还没有)"

if [ ! -d /proc/asound/C920 ]; then
  echo
  echo "════ 尝试 2: 整个 USB 设备 unbind/bind(重新枚举) ════"
  echo "1-1.3" > /sys/bus/usb/drivers/usb/unbind 2>/dev/null
  sleep 3
  echo "1-1.3" > /sys/bus/usb/drivers/usb/bind 2>/dev/null
  sleep 6
  echo "  结果: C920 声卡 $([ -d /proc/asound/C920 ] && echo 回来了 ✓ || echo 还没有)"
fi

echo
echo "════ 最终状态 ════"
echo "  arecord: $(arecord -l 2>/dev/null | grep -c C920) (1=在)"
arecord -l 2>/dev/null | grep -i c920 | sed 's/^/    /'
echo "  采集节点: $(ls /dev/snd/pcmC*D0c 2>/dev/null | tr '\n' ' ')"
echo "  视频节点: $(ls /dev/v4l/by-id/ 2>/dev/null | grep -c C920)"
echo "  astra-voice: $(systemctl is-active astra-voice)"
dmesg -T 2>/dev/null | grep -iE "1-1.3|C920" | tail -n 6 | sed 's/^/    /'
