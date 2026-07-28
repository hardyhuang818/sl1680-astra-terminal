#!/bin/bash
O="/mnt/d/Claude code/Case6_Astra/tools/_wslout"
K=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts
echo "=== 源码核对 ==="
grep -c 'gpio = <&portb 6 GPIO_ACTIVE_HIGH>' $K | xargs echo "  vol_up 的 portb6 引用数(应为0):"
grep -c 'gpios = <6 GPIO_ACTIVE_HIGH>' $K | xargs echo "  hog 的 portb6 引用数(应为1):"
grep -n "mipirst-gpios" $K
echo
cd /home/astra/sdk
set +e
source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1
D=/home/astra/sdk/build-sl1680/tmp/deploy/images/sl1680
echo "=== 重建内核 ($(date +%H:%M:%S)) ==="
bitbake linux-syna -C compile > "$O/prst_k.log" 2>&1
RC=$?; echo "  compile rc=$RC"
[ $RC -ne 0 ] && { grep -E "^ERROR|Error" "$O/prst_k.log" | head -n 8; exit 1; }
bitbake linux-syna -c deploy -f > "$O/prst_d.log" 2>&1
echo "  deploy rc=$?  ($(date +%H:%M:%S))"
echo
echo "=== DTB 字节级验证 ==="
python3 - "$D/dolphin-rdk.dtb" <<'EOF'
import sys
b = open(sys.argv[1], "rb").read()
checks = {
  "mipirst-gpios 属性": b"mipirst-gpios" in b,
  "gpio-hog": b"gpio-hog" in b,
  "line-name td7800-tp-rst": b"td7800-tp-rst" in b,
  "TD7800 command 仍在": bytes([0x29,0x06,0x9C,0x04,0x41,0x00,0x00,0x00]) in b,
  "触摸节点仍在": b"synaptics,tcm-i2c" in b,
  "volume_up 已移除": b"volume_up" not in b,
}
ok = True
for k, v in checks.items():
    print(("  √ " if v else "  ✗ ") + k); ok &= v
sys.exit(0 if ok else 1)
EOF
RC2=$?
echo
sha256sum "$D/linux_bootimgs.subimg" | cut -c1-72
cp "$D/linux_bootimgs.subimg" "/mnt/d/Claude code/Case6_Astra/SL1680_td7800_boot/boot_panelrst.subimg"
ls -la "/mnt/d/Claude code/Case6_Astra/SL1680_td7800_boot/boot_panelrst.subimg"
[ $RC2 -eq 0 ] && echo "★ 全部验证通过" || echo "★ 验证有失败项"
