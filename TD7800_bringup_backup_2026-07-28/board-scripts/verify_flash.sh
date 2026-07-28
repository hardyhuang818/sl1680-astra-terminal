#!/bin/sh
# 真·回读校验（绕开 busybox head -c 缺失）
python3 - <<'EOF'
import hashlib
n = 19110288
exp = "ca08fc5d9f2b96cab3727bc5f347c337ff8b795044b2ee38afdc33bd44262f9a"
for dev in ("/dev/mmcblk0p8", "/dev/mmcblk0p9"):
    h = hashlib.sha256(open(dev, "rb").read(n)).hexdigest()
    print(dev, h, "OK" if h == exp else "MISMATCH")
EOF
