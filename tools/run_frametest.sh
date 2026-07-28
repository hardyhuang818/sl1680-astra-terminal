#!/bin/sh
set -u
python3 - <<'PYEOF'
p="/tmp/dl_frametest"; d=open(p,"rb").read()
if d[:3]==b"\xef\xbb\xbf": d=d[3:]; open(p,"wb").write(d); print("stripped BOM")
assert d[:4]==b"\x7fELF"; print("ELF OK")
PYEOF
chmod +x /tmp/dl_frametest

echo
echo "=== 停 dl-face (dlsdk 单进程独占) ==="
systemctl stop dl-face
sleep 3

echo
echo "════════ 推帧路径诊断 (屏1 当前是黑的) ════════"
/tmp/dl_frametest 10 2>&1 | head -n 40

echo
echo "════════ 同时对比 AUX 状态 ════════"
/tmp/dl_dptest 2>&1 | grep -E "屏[0-9]|AUX读DPCD|SINK_COUNT|EDID:" | head -n 12

echo
echo "=== 恢复 dl-face (会重新枚举, 屏应该亮回来) ==="
systemctl start dl-face
sleep 36
journalctl -u dl-face --no-pager -n 10 -o cat 2>/dev/null | grep -E "发现|屏点亮" | tail -n 3
echo "dl-face: $(systemctl is-active dl-face)"
