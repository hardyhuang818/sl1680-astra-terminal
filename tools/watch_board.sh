#!/bin/sh
# Watch for the board coming back, up to ~100s. ASCII only.
i=0
while [ $i -lt 20 ]; do
  if ping -c 1 -W 2 192.168.8.186 >/dev/null 2>&1; then
    echo "  [${i}x5s] BOARD IS BACK (ping ok)"
    nc -w 4 -z 192.168.8.186 22 2>/dev/null && echo "  ssh port open too" || echo "  ssh not up yet"
    exit 0
  fi
  i=$((i+1))
  sleep 5
done
echo "  100s elapsed, still no response from 192.168.8.186"
echo "  (router 192.168.8.1 was reachable, so this is the board, not the tunnel)"
exit 1
