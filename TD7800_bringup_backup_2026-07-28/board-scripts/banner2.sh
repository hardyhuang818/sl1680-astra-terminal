#!/bin/sh
pkill -f "gst-launch-1.0 -q videotestsrc" 2>/dev/null
sleep 1
export XDG_RUNTIME_DIR=/run/user/0
export WAYLAND_DISPLAY=wayland-1
nohup gst-launch-1.0 -q videotestsrc pattern=black is-live=true \
  ! video/x-raw,width=1280,height=720,framerate=30/1 \
  ! textoverlay text="Synaptics SL1680 + TD7800 LVDS Panel" font-desc="Sans Bold 42" valignment=top ypad=250 \
  ! clockoverlay time-format="%Y-%m-%d  %A  %H:%M:%S" font-desc="Sans Bold 34" valignment=top ypad=400 halignment=center \
  ! waylandsink fullscreen=true >/tmp/banner.log 2>&1 &
sleep 3
ps | grep gst-launch | grep -v grep | head -n 1
grep -i error /tmp/banner.log 2>/dev/null | head -n 3
echo "★ 看屏: 标题 + 日期星期 + 实时秒钟"
