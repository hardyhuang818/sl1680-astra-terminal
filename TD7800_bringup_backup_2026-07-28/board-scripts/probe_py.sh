#!/bin/sh
for m in ctypes struct array mmap termios; do
  python3 -c "import $m; print('$m ok')" 2>/dev/null || echo "$m 缺失"
done
ls /usr/lib/python3*/lib-dynload/ 2>/dev/null | head -n 20
