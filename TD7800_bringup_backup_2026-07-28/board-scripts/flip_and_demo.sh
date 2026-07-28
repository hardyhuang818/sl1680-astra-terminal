#!/bin/sh
echo "=== 1. weston.ini 加 DSI-1 rotate-180 ==="
if ! grep -q "name=DSI-1" /etc/xdg/weston/weston.ini; then
cat >> /etc/xdg/weston/weston.ini <<'EOF'

[output]
name=DSI-1
transform=rotate-180
EOF
fi
grep -A3 "\[output\]" /etc/xdg/weston/weston.ini
echo
echo "=== 2. 重启 weston (清掉所有旧窗口 + 应用翻转) ==="
for p in $(ps | grep -E "gst-launch|simple-touch" | grep -v grep | awk '{print $1}'); do kill $p 2>/dev/null; done
systemctl restart weston
sleep 5
systemctl is-active weston
journalctl -u weston -b 2>/dev/null | grep -i "transform\|rotate" | tail -n 3
echo
echo "=== 3. 起触摸画板 ==="
export XDG_RUNTIME_DIR=/run/user/0
export WAYLAND_DISPLAY=wayland-1
nohup /usr/bin/weston-simple-touch >/tmp/touchdemo.log 2>&1 &
sleep 2
ps | grep simple-touch | grep -v grep | head -n 1
echo "★ 画面现在应是正的; 屏上有个黑色画板窗口, 手指在窗口里画 = 蓝色笔迹"
