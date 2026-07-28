#!/bin/sh
echo "=== 关闭前状态 ==="
for s in astra-mode astra-xiaozhi astra-voice; do
  printf "  %-16s active=%-9s enabled=%s\n" "$s" "$(systemctl is-active $s 2>/dev/null)" "$(systemctl is-enabled $s 2>/dev/null)"
done

echo
echo "=== 关闭 astra-mode(真正会掀翻本地模式的是它) ==="
systemctl disable --now astra-mode 2>&1 | sed 's/^/  /'

echo
echo "=== 确保 astra-xiaozhi 也不会被拉起来 ==="
systemctl disable --now astra-xiaozhi 2>&1 | sed 's/^/  /'
systemctl mask astra-xiaozhi 2>&1 | sed 's/^/  /'

echo
echo "=== 关闭后状态 ==="
for s in astra-mode astra-xiaozhi astra-voice astra-translate dl-face vision-wake; do
  printf "  %-16s active=%-9s enabled=%s\n" "$s" "$(systemctl is-active $s 2>/dev/null)" "$(systemctl is-enabled $s 2>/dev/null)"
done

echo
echo "=== astra-voice 没被误伤吧 ==="
echo "  NRestarts=$(systemctl show -p NRestarts --value astra-voice)"
journalctl -u astra-voice --no-pager -n 5 -o cat 2>/dev/null | tail -n 3

echo
echo "=== astra-xiaozhi 到底连的什么(回答云端托管的问题要用) ==="
systemctl cat astra-xiaozhi 2>/dev/null | grep -E "ExecStart|Description" | sed 's/^/  /'
echo "  --- 客户端里写死的协议/端点 ---"
strings /usr/bin/astra_xiaozhi 2>/dev/null | grep -iE "^ws://|^wss://|^http://|/xiaozhi|websocket|/api/" | head -n 8 | sed 's/^/  /'
