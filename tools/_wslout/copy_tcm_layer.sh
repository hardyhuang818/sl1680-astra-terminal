#!/bin/bash
SRC=/home/astra/sdk/meta-tcm2-touch
DST="/mnt/d/Claude code/Case6_Astra/meta-tcm2-touch"
echo "=== 源层结构 ==="
find "$SRC" -type f | sed "s|$SRC/||" | sort
echo
echo "=== 复制到仓库(跳过厂商 tarball，仓库根目录已有一份) ==="
mkdir -p "$DST"
cd "$SRC" || exit 1
find . -type f ! -name "*.tar.gz" ! -name "*.spkg" ! -path "*/build/*" | while read -r f; do
  mkdir -p "$DST/$(dirname "$f")"
  cp "$f" "$DST/$f"
  echo "  + $f"
done
echo
echo "=== 补丁内容自检 ==="
P="$DST/recipes-kernel/linux-drivers/synaptics-tcm2/files/0001-enable-helper-and-fix-isr-deadlock.patch"
[ -f "$P" ] || P=$(find "$DST" -name "0001-enable-helper*.patch" | head -1)
echo "  补丁: ${P#$DST/}  ($(wc -l < "$P") 行)"
python3 - "$P" <<'EOF'
import sys, io
s = io.open(sys.argv[1], encoding="utf-8", errors="replace").read()
checks = {
    "打开 ENABLE_HELPER":      "define ENABLE_HELPER" in s,
    "改 unexpected_reset":     "syna_dev_process_unexpected_reset" in s or "dev_set_up_app_fw" in s,
    "有 helper.workqueue 判断": "helper.workqueue" in s,
    "路径相对 S (a/syna_tcm2)": "a/syna_tcm2" in s,
}
ok = True
for k, v in checks.items():
    print(("  OK   " if v else "  ERR  ") + k); ok &= v
sys.exit(0 if ok else 1)
EOF
echo
echo "=== 配方 SRC_URI ==="
grep -n "SRC_URI" -A4 "$DST"/recipes-kernel/linux-drivers/synaptics-tcm2/*.bb 2>/dev/null
