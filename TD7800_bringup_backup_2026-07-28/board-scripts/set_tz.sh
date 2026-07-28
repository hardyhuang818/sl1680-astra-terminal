#!/bin/sh
echo "=== 时区文件在不在 ==="
ls /usr/share/zoneinfo/Asia/Shanghai 2>/dev/null || { echo "无 tzdata Asia/Shanghai!"; ls /usr/share/zoneinfo/ 2>/dev/null | head -n 10; }
echo "=== 设时区 ==="
if command -v timedatectl >/dev/null 2>&1; then
  timedatectl set-timezone Asia/Shanghai 2>&1 && echo "timedatectl OK"
fi
# 兜底: 手动链接
if [ -f /usr/share/zoneinfo/Asia/Shanghai ]; then
  ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
  echo "Asia/Shanghai" > /etc/timezone
fi
echo "=== 结果 ==="
date
timedatectl 2>/dev/null | head -n 5
echo "=== NTP 同步状态 ==="
systemctl is-active systemd-timesyncd 2>/dev/null
