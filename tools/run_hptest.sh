#!/bin/sh
set -u
python3 - <<'PYEOF'
p="/tmp/dl_hptest"; d=open(p,"rb").read()
if d[:3]==b"\xef\xbb\xbf": d=d[3:]; open(p,"wb").write(d); print("stripped BOM")
assert d[:4]==b"\x7fELF"; print("ELF OK")
PYEOF
chmod +x /tmp/dl_hptest
systemctl stop dl-face
sleep 3
/tmp/dl_hptest 2>&1
echo
echo "=== 板上 libusb 版本 ==="
ls -l /usr/lib/libusb-1.0.so* 2>/dev/null
strings /usr/lib/libusb-1.0.so.0 2>/dev/null | grep -iE "^1\.[0-9]+\.[0-9]+" | head -3
echo
echo "=== 内核是否支持 udev/netlink 热插拔(libusb 靠它) ==="
ls /sys/class/udev 2>/dev/null || echo "  (无 /sys/class/udev)"
pgrep -l udevd 2>/dev/null || pgrep -l systemd-udevd 2>/dev/null || echo "  (udevd 未运行?)"
echo
systemctl start dl-face
sleep 34
echo "dl-face 恢复: $(systemctl is-active dl-face)"
