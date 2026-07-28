#!/bin/sh
echo "════ dl-face 本次开机日志 ════"
journalctl -u dl-face --no-pager -o cat -b 2>/dev/null | tail -n 15 | sed 's/^/  /'
echo
echo "  状态: $(systemctl is-active dl-face)  NRestarts=$(systemctl show -p NRestarts --value dl-face)"

echo
echo "════ DL7400 在不在 USB 上 ════"
lsusb 2>/dev/null | grep -i 17e9 | sed 's/^/  /'
echo "  (空 = dock 没接或没上电)"
echo "  USB 速率:"
for d in /sys/bus/usb/devices/*/idVendor; do
  [ "$(cat $d 2>/dev/null)" = "17e9" ] && { p=$(dirname $d); echo "    $(basename $p): speed=$(cat $p/speed 2>/dev/null)"; }
done

echo
echo "════ 掉线的是什么时候 ════"
dmesg -T 2>/dev/null | grep -iE "17e9|DisplayLink|Redwood" | tail -n 8 | sed 's/^/  /'
