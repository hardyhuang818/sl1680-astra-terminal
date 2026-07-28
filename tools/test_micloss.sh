#!/bin/sh
# 真实模拟麦克风掉线：把 snd-usb-audio 从 C920 的音频接口上 unbind。
# 内核视角和拔线等价，但不动 USB 设备本身（视频接口不受影响）。
set -u

IF=$(ls /sys/bus/usb/drivers/snd-usb-audio/ 2>/dev/null | grep "^1-1\.3:" | head -n 1)
if [ -z "$IF" ]; then
  echo "!! 找不到 C920 的音频接口，放弃(不做危险操作)"
  ls /sys/bus/usb/drivers/snd-usb-audio/ | sed 's/^/    /'
  exit 1
fi
echo "C920 音频接口: $IF"

# ★安全网：不管下面发生什么，90 秒后一定把它绑回来
setsid sh -c "sleep 90; echo '$IF' > /sys/bus/usb/drivers/snd-usb-audio/bind 2>/dev/null" >/dev/null 2>&1 &
echo "已挂 90 秒兜底重绑（即使脚本中途死掉也会恢复）"
echo

echo "════ 1. 停服务，拔掉麦克风 ════"
systemctl stop astra-voice
R0=$(systemctl show -p NRestarts --value astra-voice)
echo "$IF" > /sys/bus/usb/drivers/snd-usb-audio/unbind
sleep 2
[ -d /proc/asound/C920 ] && echo "  ✗ 声卡还在，模拟失败" || echo "  ✓ /proc/asound/C920 已消失（等价于拔线）"
echo "  arecord 还看得到吗: $(arecord -l 2>/dev/null | grep -c C920) (0=没了)"

echo
echo "════ 2. 麦克风不在的情况下启动服务 ════"
systemctl start astra-voice &
sleep 18
echo "  服务状态: $(systemctl is-active astra-voice)  (期望 activating = 卡在 ExecStartPre 等待)"
echo "  wait-mic 说了什么:"
journalctl -u astra-voice --no-pager -o cat -n 10 2>/dev/null | grep "wait-mic" | tail -n 2 | sed 's/^/    /'
echo "  ★关键: 有没有在空转加载模型?"
n=$(journalctl -u astra-voice --no-pager -o cat --since "-30 seconds" 2>/dev/null | grep -c "加载模型")
echo "    最近 30 秒 '加载模型' 次数 = $n  (期望 0)"
echo "  ★关键: 有没有崩溃重启?"
R1=$(systemctl show -p NRestarts --value astra-voice)
echo "    NRestarts: $R0 -> $R1  (期望不变)"

echo
echo "════ 3. 把麦克风插回来 ════"
echo "$IF" > /sys/bus/usb/drivers/snd-usb-audio/bind
sleep 3
[ -d /proc/asound/C920 ] && echo "  ✓ 声卡回来了" || echo "  ✗ 声卡没回来"

echo
echo "════ 4. 服务应该自己继续起来 ════"
sleep 26
echo "  服务状态: $(systemctl is-active astra-voice)"
echo "  NRestarts=$(systemctl show -p NRestarts --value astra-voice)  (全程应为 $R0)"
journalctl -u astra-voice --no-pager -o cat -n 12 2>/dev/null | grep -E "wait-mic|模型就绪|开始监听|打不开" | tail -n 4 | sed 's/^/    /'

echo
echo "════ 5. 对照：旧行为长什么样 ════"
echo "  2026-07-23 13:38-13:40 麦克风掉 86 秒期间："
echo "    崩 3 次 + 每次白加载 14-17 秒模型 + NRestarts 4->7"
