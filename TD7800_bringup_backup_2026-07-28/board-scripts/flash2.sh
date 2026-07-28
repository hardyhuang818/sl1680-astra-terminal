#!/bin/sh
# 板上执行: 刷 /tmp/boot_td7800_spi.subimg 到 boot_a/b + python 回读校验
set -e
IMG=/tmp/boot_td7800_spi.subimg
SHA=9e4afa6924b6960ef1e3cd35e3cdad6c7fbbc131b6b76547417c34325ef957de
echo "==> 校验源文件"
ACT=$(sha256sum "$IMG" | cut -d' ' -f1)
[ "$ACT" = "$SHA" ] || { echo "sha 不符: $ACT"; exit 1; }
echo "    OK"
echo "==> 备份(已有 td7800 备份保留, 本轮不覆盖)"
ls -l /home/boot_*_backup*.img 2>/dev/null || echo "  (无旧备份?)"
echo "==> 刷 boot_a + boot_b"
dd if="$IMG" of=/dev/mmcblk0p8 bs=1M 2>/dev/null
dd if="$IMG" of=/dev/mmcblk0p9 bs=1M 2>/dev/null
sync
echo "==> python 回读校验"
python3 - <<'EOF'
import hashlib
n = 19110288
exp = "9e4afa6924b6960ef1e3cd35e3cdad6c7fbbc131b6b76547417c34325ef957de"
ok = True
for dev in ("/dev/mmcblk0p8", "/dev/mmcblk0p9"):
    h = hashlib.sha256(open(dev, "rb").read(n)).hexdigest()
    good = h == exp
    ok &= good
    print(" ", dev, "OK" if good else "MISMATCH " + h)
raise SystemExit(0 if ok else 1)
EOF
echo "==> 校验通过, 重启"
( sleep 1; reboot ) >/dev/null 2>&1 &
echo "reboot 已下发"
