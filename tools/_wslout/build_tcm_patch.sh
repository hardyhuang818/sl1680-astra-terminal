#!/bin/bash
R=/home/astra/sdk/meta-tcm2-touch/recipes-kernel/linux-drivers/synaptics-tcm2/synaptics-tcm2_1.8.0.bb
O="/mnt/d/Claude code/Case6_Astra/tools/_wslout"
echo "=== 1. recipe 加补丁 ==="
python3 - "$R" <<'PYEOF'
import io, sys
p = sys.argv[1]
s = io.open(p, encoding="utf-8").read()
if "0001-enable-helper" in s:
    print("  已加"); raise SystemExit
old = 'SRC_URI = "file://synaptics_tcm2_touchcomm_tddi_v1.8.0.tar.gz"'
new = ('SRC_URI = "file://synaptics_tcm2_touchcomm_tddi_v1.8.0.tar.gz \\\n'
       '           file://0001-enable-helper-and-fix-isr-deadlock.patch \\\n'
       '"')
assert s.count(old) == 1, "SRC_URI 未找到"
s = s.replace(old, new)
io.open(p, "w", encoding="utf-8").write(s)
print("  已加入 SRC_URI")
PYEOF
grep -n -A3 "^SRC_URI" $R
echo
cd /home/astra/sdk
set +e
source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1
echo "=== 2. 重建触摸驱动 ($(date +%H:%M:%S)) ==="
bitbake -c cleansstate synaptics-tcm2 > "$O/tcm_clean.log" 2>&1
bitbake synaptics-tcm2 > "$O/tcm_build.log" 2>&1
RC=$?
echo "  rc=$RC ($(date +%H:%M:%S))"
if [ $RC -ne 0 ]; then
  grep -E "^ERROR" "$O/tcm_build.log" | head -n 8
  L=$(grep "Logfile of failure stored in:" "$O/tcm_build.log" | tail -1 | sed 's/.*stored in: //')
  [ -f "$L" ] && tail -n 20 "$L" | cut -c1-170
  exit 1
fi
echo "=== 3. 验证补丁真的应用了 ==="
S=/home/astra/sdk/build-sl1680/tmp/work/sl1680-poky-linux/synaptics-tcm2/1.8.0/synaptics_tcm2_touchcomm_tddi_v1.8.0/source/synaptics_tcm2
grep -q "^#define ENABLE_HELPER" $S/syna_tcm2.h && echo "  √ ENABLE_HELPER 已开" || echo "  ✗ ENABLE_HELPER 未开"
grep -q "if (!tcm->helper.workqueue)" $S/syna_tcm2.c && echo "  √ ISR 死锁修复已应用" || echo "  ✗ ISR 修复未应用"
echo
echo "=== 4. 产物 ==="
K=$(find /home/astra/sdk/build-sl1680/tmp/work -path "*synaptics-tcm2*" -name "synaptics_tcm2.ko" ! -path "*/.debug/*" 2>/dev/null | head -1)
echo "  $K"
ls -la "$K"
strings "$K" 2>/dev/null | grep -c "helper work" | xargs echo "  含 helper 字样:"
cp "$K" "/mnt/d/Claude code/Case6_Astra/SL1680_td7800_boot/synaptics_tcm2_helper.ko"
sha256sum "$K" | cut -c1-72
