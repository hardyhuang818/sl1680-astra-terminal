#!/bin/sh
echo "=== 现有 gst 进程 ==="
ps | grep gst-launch | grep -v grep
echo "=== 全杀 ==="
for p in $(ps | grep gst-launch | grep -v grep | awk '{print $1}'); do kill $p 2>/dev/null; done
sleep 2
ps | grep gst-launch | grep -v grep || echo "(已清空)"
echo "=== 起新横幅 ==="
export XDG_RUNTIME_DIR=/run/user/0
export WAYLAND_DISPLAY=wayland-1
nohup gst-launch-1.0 -q videotestsrc pattern=black is-live=true \
  ! video/x-raw,width=1280,height=720,framerate=30/1 \
  ! textoverlay text="Synaptics SL1680 + TD7800 LVDS Panel" font-desc="Sans Bold 42" valignment=top ypad=250 \
  ! clockoverlay time-format="%Y-%m-%d  %A  %H:%M:%S" font-desc="Sans Bold 34" valignment=top ypad=400 halignment=center \
  ! waylandsink fullscreen=true >/tmp/banner.log 2>&1 &
sleep 3
ps | grep gst-launch | grep -v grep
grep -i -E "error|critical" /tmp/banner.log | head -n 2
echo "★ 屏上现在应是: 标题 + 2026-07-28 Tuesday + 走秒时钟"
