#!/bin/sh
set -e
IMG=/tmp/boot_td7800_margin.subimg
SHA=9a86143dac2f0c7650a6ec8d9e113951898498229445ee5a21ba2528c78a8a9f
ACT=$(sha256sum "$IMG" | cut -d' ' -f1)
[ "$ACT" = "$SHA" ] || { echo "sha 不符: $ACT"; exit 1; }
echo "源文件校验 OK"
dd if="$IMG" of=/dev/mmcblk0p8 bs=1M 2>/dev/null
dd if="$IMG" of=/dev/mmcblk0p9 bs=1M 2>/dev/null
sync
python3 - <<'EOF'
import hashlib
n = 19110288
exp = "9a86143dac2f0c7650a6ec8d9e113951898498229445ee5a21ba2528c78a8a9f"
ok = True
for dev in ("/dev/mmcblk0p8", "/dev/mmcblk0p9"):
    h = hashlib.sha256(open(dev, "rb").read(n)).hexdigest()
    good = h == exp; ok &= good
    print(" ", dev, "OK" if good else "MISMATCH " + h)
raise SystemExit(0 if ok else 1)
EOF
echo "回读校验通过, 重启"
( sleep 1; reboot ) >/dev/null 2>&1 &
echo done
