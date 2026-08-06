#!/bin/bash
O="/mnt/d/Claude code/Case6_Astra/tools/_wslout"
DST="/mnt/d/Claude code/Case6_Astra/SL1680_td7800_boot"
cd /home/astra/sdk || exit 1
set +e
source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1
D=/home/astra/sdk/build-sl1680/tmp/deploy/images/sl1680

echo "=== 1. 重建内核 $(date +%H:%M:%S) ==="
bitbake linux-syna -C compile > "$O/eb_k.log" 2>&1
RC=$?; echo "  compile rc=$RC"
[ $RC -ne 0 ] && { grep -E "^ERROR" "$O/eb_k.log" | head -8; exit 1; }
bitbake linux-syna -c deploy -f > "$O/eb_d.log" 2>&1
echo "  deploy rc=$? ($(date +%H:%M:%S))"

echo "=== 2. DTB 验证 ==="
python3 - "$D/dolphin-rdk.dtb" <<'EOF'
import sys
b = open(sys.argv[1], "rb").read()
c = {"ebi2c 节点":        b"ebi2c" in b,
     "i2c-gpio 驱动":     b"i2c-gpio" in b,
     "触摸节点仍在":       b"synaptics,tcm-i2c" in b,
     "TD7800 面板时序仍在": bytes([0x29,0x06,0x9C,0x04,0x41,0,0,0]) in b}
ok = True
for k, v in c.items():
    print(("  OK   " if v else "  ERR  ") + k); ok &= v
sys.exit(0 if ok else 1)
EOF
[ $? -ne 0 ] && { echo "  DTB 验证失败"; exit 1; }

echo "=== 3. 打包 ==="
cp "$D/linux_bootimgs.subimg" "$DST/boot_ebi2c.subimg"
echo "  boot sha256: $(sha256sum "$D/linux_bootimgs.subimg" | cut -c1-64)"
ls -la "$DST/boot_ebi2c.subimg"
echo "完成"
