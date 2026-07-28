#!/bin/sh
for p in $(ps | grep gst-launch | grep -v grep | awk '{print $1}'); do kill $p 2>/dev/null; done
sleep 2
export XDG_RUNTIME_DIR=/run/user/0
export WAYLAND_DISPLAY=wayland-1
nohup gst-launch-1.0 -q videotestsrc pattern=black is-live=true \
  ! video/x-raw,width=1280,height=720,framerate=30/1 \
  ! textoverlay text="Synaptics SL1680
TD7800 LVDS Panel" font-desc="Sans Bold 40" valignment=top ypad=170 line-alignment=center \
  ! clockoverlay time-format="%Y-%m-%d  %A    %H:%M:%S" font-desc="Sans Bold 26" valignment=top ypad=450 halignment=center \
  ! waylandsink fullscreen=true >/tmp/banner.log 2>&1 &
sleep 3
ps | grep gst-launch | grep -v grep | head -n 1
echo "OK"
