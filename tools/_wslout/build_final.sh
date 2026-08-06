#!/bin/bash
O="/mnt/d/Claude code/Case6_Astra/tools/_wslout"
DST="/mnt/d/Claude code/Case6_Astra/SL1680_td7800_boot"
cd /home/astra/sdk
set +e
source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1
D=/home/astra/sdk/build-sl1680/tmp/deploy/images/sl1680

echo "=== 1. 重建内核(LCD_RESET hog) $(date +%H:%M:%S) ==="
bitbake linux-syna -C compile > "$O/fin_k.log" 2>&1
RC=$?; echo "  compile rc=$RC"
[ $RC -ne 0 ] && { grep -E "^ERROR" "$O/fin_k.log" | head -6; exit 1; }
bitbake linux-syna -c deploy -f > "$O/fin_d.log" 2>&1
echo "  deploy rc=$? ($(date +%H:%M:%S))"

echo "=== 2. DTB 验证 ==="
python3 - "$D/dolphin-rdk.dtb" <<'EOF'
import sys
b=open(sys.argv[1],"rb").read()
c={"td7800-lcd-rst hog": b"td7800-lcd-rst" in b,
   "td7800-tp-rst hog": b"td7800-tp-rst" in b,
   "mipirst 已移除": b"mipirst-gpios" not in b,
   "TD7800 command": bytes([0x29,0x06,0x9C,0x04,0x41,0,0,0]) in b,
   "触摸节点": b"synaptics,tcm-i2c" in b}
ok=True
for k,v in c.items(): print(("  √ " if v else "  ✗ ")+k); ok&=v
sys.exit(0 if ok else 1)
EOF
[ $? -ne 0 ] && { echo "  DTB 验证失败"; exit 1; }

echo "=== 3. 打包驱动 + boot ==="
K=$(find /home/astra/sdk/build-sl1680/tmp/work -path "*synaptics-tcm2*" -name "synaptics_tcm2.ko" ! -path "*/.debug/*" | head -1)
cp "$K" "$DST/synaptics_tcm2_helper.ko"
cp "$D/linux_bootimgs.subimg" "$DST/boot_final.subimg"
echo "  ko:   $(sha256sum "$K" | cut -c1-64)"
echo "  boot: $(sha256sum "$D/linux_bootimgs.subimg" | cut -c1-64)"
ls -la "$DST/boot_final.subimg" "$DST/synaptics_tcm2_helper.ko"
echo "★ 完成"
