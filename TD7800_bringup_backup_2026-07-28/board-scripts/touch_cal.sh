#!/bin/sh
echo "=== 1. 写 udev 校准规则 (X 轴镜像) ==="
cat > /etc/udev/rules.d/99-td7800-touch-cal.rules <<'EOF'
ACTION=="add|change", KERNEL=="event*", ATTRS{name}=="synaptics_tcm_touch", ENV{LIBINPUT_CALIBRATION_MATRIX}="-1 0 1 0 1 0"
EOF
cat /etc/udev/rules.d/99-td7800-touch-cal.rules
udevadm control --reload
udevadm trigger --subsystem-match=input --action=change
sleep 1
udevadm info /dev/input/event2 | grep -i CALIBRATION
echo
echo "=== 2. 重启 weston 应用 + 重开画板 ==="
for p in $(ps | grep simple-touch | grep -v grep | awk '{print $1}'); do kill $p 2>/dev/null; done
systemctl restart weston
sleep 5
export XDG_RUNTIME_DIR=/run/user/0
export WAYLAND_DISPLAY=wayland-1
nohup /usr/bin/weston-simple-touch >/tmp/touchdemo.log 2>&1 &
sleep 2
ps | grep simple-touch | grep -v grep | head -n 1
echo "★ 再画一次: 左右应该正了"
