#!/bin/sh
# ASCII only: the OpenWrt jump host locale is minimal.
echo "=== board 192.168.8.186 ==="
ping -c 4 -W 2 192.168.8.186 2>&1 | tail -n 2

echo
echo "=== board port 22 (in case ICMP is filtered) ==="
if nc -w 4 -z 192.168.8.186 22 2>/dev/null; then
  echo "  22 OPEN -> only ping is blocked"
else
  echo "  22 closed too -> board really is offline"
fi

echo
echo "=== what is 192.168.8.171 ==="
if nc -w 3 -z 192.168.8.171 22 2>/dev/null; then
  echo "  ssh open"
else
  echo "  ssh closed"
fi
for p in 80 443 8080 53; do
  nc -w 2 -z 192.168.8.171 $p 2>/dev/null && echo "  port $p open"
done

echo
echo "=== link to BE3600 router ==="
ping -c 2 -W 2 192.168.8.1 2>&1 | tail -n 2
