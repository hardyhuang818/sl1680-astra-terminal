#!/bin/sh
echo "=== weston.ini 现状 ==="
for f in /etc/xdg/weston/weston.ini /root/.config/weston.ini; do
  [ -f "$f" ] && { echo "-- $f:"; cat "$f"; }
done
[ -f /etc/xdg/weston/weston.ini ] || echo "(无 /etc/xdg/weston/weston.ini)"
echo
echo "=== weston 服务定义 ==="
grep -E "ExecStart|Environment" /lib/systemd/system/weston*.service /etc/systemd/system/weston*.service 2>/dev/null | head -n 6
echo
echo "=== weston 日志里的输入设备 ==="
journalctl -u weston -b 2>/dev/null | grep -i -E "input|touch|libinput|seat" | tail -n 15
echo
echo "=== weston 日志里的输出/transform ==="
journalctl -u weston -b 2>/dev/null | grep -i -E "output|DSI|transform" | tail -n 8
