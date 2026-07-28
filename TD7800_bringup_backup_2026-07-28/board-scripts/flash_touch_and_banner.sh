#!/bin/sh
echo "=== 1. 烧触摸版 boot (不重启) ==="
IMG=/tmp/boot_td7800_touch.subimg
SHA=0aa901725795467ba867e5a11982fadc6a606b7003f89393d327a0fd263dac75
ACT=$(sha256sum "$IMG" | cut -d' ' -f1)
[ "$ACT" = "$SHA" ] || { echo "sha 不符: $ACT"; exit 1; }
dd if="$IMG" of=/dev/mmcblk0p8 bs=1M 2>/dev/null
dd if="$IMG" of=/dev/mmcblk0p9 bs=1M 2>/dev/null
sync
python3 - <<'EOF'
import hashlib
exp = "0aa901725795467ba867e5a11982fadc6a606b7003f89393d327a0fd263dac75"
for dev in ("/dev/mmcblk0p8", "/dev/mmcblk0p9"):
    h = hashlib.sha256(open(dev, "rb").read(19110288)).hexdigest()
    print(" ", dev, "OK" if h == exp else "MISMATCH!")
EOF
echo "(重启后触摸生效, 先不重启)"
echo
echo "=== 2. 展示横幅 ==="
grep -E "Environment" /etc/systemd/system/dl-face.service 2>/dev/null | head -n 4
pkill -f "textoverlay" 2>/dev/null
export XDG_RUNTIME_DIR=/run/user/0
export WAYLAND_DISPLAY=wayland-1
[ -S /run/user/0/wayland-1 ] || WAYLAND_DISPLAY=wayland-0
ls /run/user/0/ 2>/dev/null | head -n 5
nohup gst-launch-1.0 -q videotestsrc pattern=black is-live=true \
  ! video/x-raw,width=1280,height=720,framerate=30/1 \
  ! textoverlay text="Synaptics SL1680 + TD7800 LVDS Panel" font-desc="Sans Bold 42" \
  ! waylandsink fullscreen=true >/tmp/banner.log 2>&1 &
sleep 3
ps | grep gst-launch | grep -v grep | head -n 2
tail -n 3 /tmp/banner.log 2>/dev/null
echo "★ 看屏: 黑底白字横幅"
