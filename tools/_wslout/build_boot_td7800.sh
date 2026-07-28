#!/bin/bash
# 重建 linux-syna boot 镜像 (dolphin-rdk.dts 已打 TD7800 补丁)
O="/mnt/d/Claude code/Case6_Astra/tools/_wslout"
cd /home/astra/sdk
set +e
source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1
D=/home/astra/sdk/build-sl1680/tmp/deploy/images/sl1680

echo "== 补丁确认(工作源码里) =="
grep -c "0x9C 0x04 0x41" tmp/work-shared/sl1680/kernel-source/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts

echo "== 记录旧产物时间戳 =="
ls -la --time-style=+%H:%M:%S "$D/linux_bootimgs.subimg" "$D/dolphin-rdk.dtb" 2>/dev/null | awk '{print $6, $7}'

echo "== bitbake linux-syna -C compile ($(date +%H:%M:%S)) =="
bitbake linux-syna -C compile > "$O/kcompile.log" 2>&1
RC1=$?
echo "rc=$RC1  ($(date +%H:%M:%S))"
if [ $RC1 -ne 0 ]; then grep -E "^ERROR" "$O/kcompile.log" | head -n 8; exit 1; fi

echo "== bitbake linux-syna -c deploy -f =="
bitbake linux-syna -c deploy -f > "$O/kdeploy.log" 2>&1
RC2=$?
echo "rc=$RC2  ($(date +%H:%M:%S))"
if [ $RC2 -ne 0 ]; then grep -E "^ERROR" "$O/kdeploy.log" | head -n 8; exit 1; fi

echo "== 新产物 =="
ls -la --time-style=+%H:%M:%S "$D/linux_bootimgs.subimg" "$D/dolphin-rdk.dtb" | awk '{print $5, $6, $7}'

echo "== 验证1: deploy 的 dolphin-rdk.dtb 内容 =="
python3 - "$D/dolphin-rdk.dtb" <<'EOF'
import sys
b = open(sys.argv[1], "rb").read()
w1280 = (1280).to_bytes(4, "big")
checks = {
  "dsi_panel 节点名": b"dsi_panel" in b,
  "command 里 LVCFG(9C 04 41, PCLKDIV=4)": bytes([0x29,0x06,0x9C,0x04,0x41,0x00,0x00,0x00]) in b,
  "command 里 DSI_LANEENABLE 0x1F": bytes([0x29,0x06,0x10,0x02,0x1F,0x00,0x00,0x00]) in b,
  "HTIM1 字节(1E 00 3C 00)": bytes([0x29,0x06,0x54,0x04,0x1E,0x00,0x3C,0x00]) in b,
  "旧RPi command(0C@0164) 已消失": bytes([0x29,0x06,0x64,0x01,0x0C,0x00,0x00,0x00]) not in b,
}
ok = True
for k, v in checks.items():
    print(("  ✓" if v else "  ✗"), k); ok &= v
sys.exit(0 if ok else 1)
EOF
RC3=$?

echo "== 验证2: linux_bootimgs.subimg 内嵌同一份 DTB =="
python3 - "$D/linux_bootimgs.subimg" <<'EOF'
import sys
b = open(sys.argv[1], "rb").read()
pat = bytes([0x29,0x06,0x9C,0x04,0x41,0x00,0x00,0x00])
idx = b.find(pat)
print("  subimg 大小:", len(b))
print(("  ✓ 内嵌DTB含TD7800 command, 偏移 " + hex(idx)) if idx >= 0 else "  ✗ subimg 里找不到新 command!")
sys.exit(0 if idx >= 0 else 1)
EOF
RC4=$?

sha256sum "$D/linux_bootimgs.subimg" | cut -c1-72
[ $RC3 -eq 0 ] && [ $RC4 -eq 0 ] && echo "★ 全部验证通过" || echo "★ 验证失败,勿烧录"
