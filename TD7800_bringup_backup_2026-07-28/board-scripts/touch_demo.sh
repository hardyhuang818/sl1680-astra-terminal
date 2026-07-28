#!/bin/sh
echo "=== 可用的 weston 演示客户端 ==="
ls /usr/bin/ | grep -E "weston-simple|weston-touch|weston-flower|weston-eventdemo"
echo
echo "=== 撤横幅 ==="
for p in $(ps | grep gst-launch | grep -v grep | awk '{print $1}'); do kill $p 2>/dev/null; done
sleep 1
export XDG_RUNTIME_DIR=/run/user/0
export WAYLAND_DISPLAY=wayland-1
if [ -x /usr/bin/weston-simple-touch ]; then
  echo "=== 启动 weston-simple-touch (触摸绘画) ==="
  nohup /usr/bin/weston-simple-touch >/tmp/touchdemo.log 2>&1 &
  sleep 2
  ps | grep simple-touch | grep -v grep | head -n 1
  echo "★ 现在用手指在屏上画 —— 应该出现蓝色笔迹"
else
  echo "(无 simple-touch, 用 flower 兜底: 可拖拽的花)"
  nohup /usr/bin/weston-flower >/tmp/touchdemo.log 2>&1 &
  sleep 2
  echo "★ 现在拖拽屏上的花"
fi
