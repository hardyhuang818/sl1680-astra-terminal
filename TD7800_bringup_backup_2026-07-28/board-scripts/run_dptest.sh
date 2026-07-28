#!/bin/sh
set -u
python3 - <<'PYEOF'
p="/tmp/dl_dptest"; d=open(p,"rb").read()
if d[:3]==b"\xef\xbb\xbf": d=d[3:]; open(p,"wb").write(d); print("去BOM")
assert d[:4]==b"\x7fELF"; print("ELF OK")
PYEOF
chmod +x /tmp/dl_dptest

echo
echo "=== 先看 dl-face 现在认为有几块屏 ==="
journalctl -u dl-face --no-pager -n 20 -o cat 2>/dev/null | grep -E "发现|屏点亮|数量变化" | tail -n 4

echo
echo "=== 停 dl-face(dlsdk 单进程独占) ==="
systemctl stop dl-face
sleep 3

echo
echo "════════════ DP AUX 检测实测 ════════════"
/tmp/dl_dptest 2>&1 | head -n 45

echo
echo "=== 恢复 dl-face ==="
systemctl start dl-face
sleep 34
journalctl -u dl-face --no-pager -n 10 -o cat 2>/dev/null | grep -E "发现|屏点亮" | tail -n 3
echo "dl-face: $(systemctl is-active dl-face)"
