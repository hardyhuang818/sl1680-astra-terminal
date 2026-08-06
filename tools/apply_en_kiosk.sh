#!/bin/sh
# 剥 BOM -> reload -> 重启 kiosk -> 确认它真的在跑 /en
f=/etc/systemd/system/astra-kiosk.service
python3 - <<'EOF'
p='/etc/systemd/system/astra-kiosk.service'
d=open(p,'rb').read()
if d[:3]==b'\xef\xbb\xbf':
    open(p,'wb').write(d[3:]); print('BOM stripped', len(d)-3)
else:
    print('clean', len(d))
EOF
grep '^ExecStart=' $f
systemctl daemon-reload
systemctl restart astra-kiosk
sleep 6
echo "kiosk  : $(systemctl is-active astra-kiosk)"
echo "webctl : $(systemctl is-active astra-webctl)"
echo "--- cog cmdline ---"
for p in /proc/[0-9]*/cmdline; do
  tr '\0' ' ' < "$p" 2>/dev/null | grep -q '^/usr/bin/cog' && { tr '\0' ' ' < "$p"; echo; }
done
echo "--- kiosk journal (tail) ---"
journalctl -u astra-kiosk -n 12 --no-pager
