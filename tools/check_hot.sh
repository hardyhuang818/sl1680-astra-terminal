#!/bin/sh
echo "=== 实际命令行(确认参数没退回旧值) ==="
for p in 909 1344; do
  printf "  pid=%s: " "$p"
  tr '\0' ' ' < /proc/$p/cmdline 2>/dev/null; echo
done
echo
echo "=== dl-face 服务里的 ExecStart ==="
systemctl show -p ExecStart --value dl-face | head -c 400; echo
echo
echo "=== astra_voice 最近在干嘛 ==="
journalctl -u astra-voice --no-pager -n 30 -o cat 2>/dev/null | tail -n 12
echo
echo "=== dl_face 最近日志 ==="
journalctl -u dl-face --no-pager -n 20 -o cat 2>/dev/null | tail -n 8
echo
echo "=== 线程数(看是不是某个线程空转) ==="
for p in 909 1344; do
  n=$(ls /proc/$p/task 2>/dev/null | wc -l)
  printf "  pid=%s 线程数=%s\n" "$p" "$n"
done
echo
echo "=== 处于 D 状态(I/O 等待)的进程 ==="
for d in /proc/[0-9]*; do
  s=$(awk '{print $3}' $d/stat 2>/dev/null)
  [ "$s" = "D" ] && printf "  %s %s\n" "$(basename $d)" "$(cat $d/comm 2>/dev/null)"
done
echo "(空 = 没有)"
echo
echo "=== 温度/降频 ==="
for z in /sys/class/thermal/thermal_zone*/temp; do
  [ -f "$z" ] && printf "  %s = %s\n" "$z" "$(cat $z)"
done
echo
echo "=== 屏幕角色 ==="
cat /tmp/astra_screen_mode.txt 2>/dev/null | sed 's/^/  /'
echo "(空 = 文件不存在，dl_face 用默认)"
