#!/bin/sh
python3 - <<'EOF'
p='/home/voice/webctl/index_en.html'
d=open(p,'rb').read()
if d[:3]==b'\xef\xbb\xbf':
    open(p,'wb').write(d[3:]); print('BOM stripped ->', len(d)-3)
else: print('clean', len(d))
EOF
systemctl restart astra-kiosk
sleep 7
echo "kiosk=$(systemctl is-active astra-kiosk) webctl=$(systemctl is-active astra-webctl) served=$(curl -s -o /dev/null -w '%{http_code} %{size_download}B' http://127.0.0.1:8080/en)"
echo "6col=$(curl -s http://127.0.0.1:8080/en | grep -c 'repeat(6,1fr)')  loaded=$(journalctl -u astra-kiosk --since '-20s' --no-pager | grep -c 'Loaded successfully')"
echo
echo "===== 舵机 PCA9685 ====="
python3 /home/voice/pca9685.py scan 2>&1 | tail -20
echo "-- 直接读 0x40 / 0x70 的 MODE1 --"
python3 - <<'EOF'
import os, ctypes
libc = ctypes.CDLL(None, use_errno=True)
for addr in (0x40, 0x41, 0x70):
    for name, req in (("SLAVE",0x0703), ("FORCE",0x0706)):
        fd = os.open("/dev/i2c-0", os.O_RDWR)
        try:
            if libc.ioctl(fd, ctypes.c_ulong(req), ctypes.c_ulong(addr)) < 0:
                print("  %#04x %-5s ioctl 失败(被内核驱动占用)" % (addr, name)); continue
            try:
                os.write(fd, bytes([0x00]))
                v = os.read(fd, 1)[0]
                print("  %#04x %-5s MODE1=0x%02x  %s" % (addr, name, v,
                      "SLEEP" if v & 0x10 else "awake"))
            except OSError as e:
                print("  %#04x %-5s 写/读失败: %s" % (addr, name, e))
        finally:
            os.close(fd)
EOF
