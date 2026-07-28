#!/bin/sh
echo "=== dl_face 完整启动日志(看 3 块屏是什么) ==="
journalctl -u dl-face --no-pager -o cat 2>/dev/null | grep -E "发现|屏点亮" | tail -n 6
echo
echo "=== DL7400 USB ==="
lsusb 2>/dev/null | grep -i 17e9 | sed 's/^/  /'
echo
echo "=== 像素带宽估算 ==="
echo "  3840x2160 BGRA = 33.2 MB/帧  x2 屏 x5fps = 332 MB/s"
echo "  2880x1800 BGRA = 20.7 MB/帧  x1 屏 x5fps = 104 MB/s"
echo "  合计约 436 MB/s  (之前 2 块屏时约 145 MB/s)"
echo
echo "=== astra-mode: 现在能不能摸到 PC(同网段了!) ==="
ping -c 2 -W 2 192.168.5.166 >/dev/null 2>&1 && echo "  PC 192.168.5.166 可达 ✓" || echo "  PC 不可达"
if curl -m 3 -s -o /dev/null http://192.168.5.166:8000/ 2>/dev/null; then
  echo "  ⚠️ 8000 端口有服务在听 -> astra-mode 会切走 astra-voice!"
else
  echo "  8000 端口无服务 -> 暂时不会切(但 PC 一开服务就会切)"
fi
echo
echo "=== 最近 30 条识别，看误触发多不多 ==="
journalctl -u astra-voice --no-pager -o cat 2>/dev/null | grep -c "^\[你 \]" | sed 's/^/  累计识别次数: /'
journalctl -u astra-voice --no-pager -o cat 2>/dev/null | grep "^\[你 \]" | tail -n 8
echo
echo "=== 视觉唤醒触发频率 ==="
journalctl -u astra-voice --no-pager -o cat 2>/dev/null | grep -c "检测到有人靠近" | sed 's/^/  累计唤醒: /'
echo
echo "=== 存了多少段音频(每次误触发都存) ==="
ls /home/voice/segs 2>/dev/null | wc -l | sed 's/^/  /'
