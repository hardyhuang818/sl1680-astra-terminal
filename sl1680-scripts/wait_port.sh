#!/bin/sh
# 等 webctl 的 127.0.0.1:8080 就绪（最多 30 秒）。astra-kiosk.service 的 ExecStartPre 用。
i=0
while [ "$i" -lt 30 ]; do
  python3 -c 'import socket,sys; s=socket.socket(); s.settimeout(1); sys.exit(s.connect_ex(("127.0.0.1",8080)))' && exit 0
  i=$((i+1))
  sleep 1
done
echo "webctl :8080 30 秒未就绪" >&2
exit 1
