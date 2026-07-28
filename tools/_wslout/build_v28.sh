#!/bin/bash
# v2.8 交付验证构建：cleanall 干净构建 + rootfs 三件套 + 全套验收
O="/mnt/d/Claude code/Case6_Astra/tools/_wslout"
R='/mnt/d/Claude code/Case6_Astra/meta-dlsdk'
ts() { date '+%H:%M:%S'; }

echo "[$(ts)] ★ 同步 layer (含 .git 排除)"
rsync -a --delete --delete-excluded \
  --exclude='.git' --exclude='*.repo_stale_*' --exclude='*.pre_selfheal' \
  --exclude='*.orig' --exclude='*DANGEROUS*' \
  "$R/" /home/astra/sdk/meta-dlsdk/
echo "  bbappend 清单: $(find /home/astra/sdk/meta-dlsdk -name '*.bbappend' | wc -l) 个"
find /home/astra/sdk/meta-dlsdk -name "*.bbappend" | sed 's|.*/meta-dlsdk/|    |'

cd /home/astra/sdk
set +e
source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1
D=/home/astra/sdk/build-sl1680/tmp/deploy/images/sl1680

echo "[$(ts)] ★ cleanall linux-syna (清掉 work-shared 手改, 让补丁接管)"
bitbake -c cleanall linux-syna > "$O/v28_cleanall.log" 2>&1
echo "  rc=$?"

echo "[$(ts)] ★ 重建 linux-syna (do_patch 应用 186 行补丁)"
bitbake linux-syna > "$O/v28_kernel.log" 2>&1
RC=$?
echo "  rc=$RC ($(ts))"
if [ $RC -ne 0 ]; then
  echo "❌ 内核构建失败:"; grep -E "^ERROR" "$O/v28_kernel.log" | head -6
  L=$(grep "Logfile of failure stored in:" "$O/v28_kernel.log" | tail -1 | sed 's/.*stored in: //')
  [ -f "$L" ] && tail -20 "$L" | cut -c1-180
  exit 1
fi

echo "[$(ts)] ★ 验证1: 补丁确实应用到了干净源码"
K=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts
for k in "Byte_clk = <65300>" "0x41 0x00 0x00 0x00" "synaptics_tcm@2c" "spi2_data_pmux" "interrupt-parent = <&porta>"; do
  grep -q "$k" "$K" && echo "  √ $k" || echo "  ✗ 缺 $k"
done

echo "[$(ts)] ★ 验证2: DTB 字节级"
python3 - "$D/dolphin-rdk.dtb" <<'EOF'
import sys
b = open(sys.argv[1], "rb").read()
for name, pat, want in [
  ("LVCFG 0x41", bytes([0x29,0x06,0x9C,0x04,0x41,0x00,0x00,0x00]), True),
  ("HTIM1", bytes([0x29,0x06,0x54,0x04,0x1E,0x00,0x3C,0x00]), True),
  ("tcm 节点", b"synaptics,tcm-i2c", True),
  ("spidev", b"rohm,dh2228fv", True),
  ("旧RPi命令", bytes([0x29,0x06,0x64,0x01,0x0C,0x00,0x00,0x00]), False)]:
    ok = (pat in b) == want
    print(("  √ " if ok else "  ✗ ") + name)
EOF

echo "[$(ts)] ★ 镜像构建 (先 clean 防 pseudo 脏状态)"
bitbake -c clean astra-media > "$O/v28_imgclean.log" 2>&1
bitbake astra-media > "$O/v28_image.log" 2>&1
RC=$?
echo "  rc=$RC ($(ts))"
if [ $RC -ne 0 ]; then
  echo "❌ 镜像构建失败:"; grep -E "^ERROR" "$O/v28_image.log" | head -8
  L=$(grep "Logfile of failure stored in:" "$O/v28_image.log" | tail -1 | sed 's/.*stored in: //')
  [ -f "$L" ] && tail -20 "$L" | cut -c1-180
  exit 1
fi

echo "[$(ts)] ★ 验证3: rootfs 三件套 (debugfs 直查 ext4)"
E=$(ls -t "$D"/astra-media-sl1680.rootfs*.ext4 2>/dev/null | head -1)
[ -z "$E" ] && E=$(ls -t "$D"/*.ext4 2>/dev/null | head -1)
echo "  rootfs: $E"
debugfs -R "cat /etc/udev/rules.d/99-td7800-touch-cal.rules" "$E" 2>/dev/null | grep -q "CALIBRATION" && echo "  √ 触摸校准规则" || echo "  ✗ 触摸校准规则缺失"
debugfs -R "cat /etc/xdg/weston/weston.ini" "$E" 2>/dev/null | grep -q "rotate-180" && echo "  √ weston rotate-180" || echo "  ✗ weston 翻转缺失"
debugfs -R "stat /usr/share/zoneinfo/Asia/Shanghai" "$E" 2>/dev/null | grep -q Inode && echo "  √ zoneinfo Asia/Shanghai" || echo "  ✗ zoneinfo 缺失"
debugfs -R "cat /etc/timezone" "$E" 2>/dev/null | head -1
debugfs -R "stat /etc/localtime" "$E" 2>/dev/null | grep -E "Type:|Fast link dest" | head -2

echo "[$(ts)] ★ 验证4: boot 子镜像含 TD7800 command"
python3 - "$D/linux_bootimgs.subimg" <<'EOF'
import sys
b = open(sys.argv[1], "rb").read()
pat = bytes([0x29,0x06,0x9C,0x04,0x41,0x00,0x00,0x00])
i = b.find(pat)
print(("  √ subimg 内嵌 TD7800 command @ " + hex(i)) if i >= 0 else "  ✗ subimg 缺 command!")
EOF

echo "[$(ts)] ★ .swu 解剖 (看它更新哪些分区)"
mkdir -p /tmp/swu && cd /tmp/swu && rm -f *
cpio -it < "$D/astra-media.swu" 2>/dev/null | head -20
cpio -i --to-stdout sw-description < "$D/astra-media.swu" 2>/dev/null | head -60

echo "[$(ts)] ★ 产物指纹"
sha256sum "$D/astra-media.swu" "$D/linux_bootimgs.subimg" 2>/dev/null | cut -c1-100
ls -la "$D/astra-media.swu"
echo "[$(ts)] ★★★ v2.8 构建全流程完成"
