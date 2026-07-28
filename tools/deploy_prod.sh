#!/bin/sh
set -u
python3 - <<'PYEOF'
import os
p="/tmp/dl_face.prod"; d=open(p,"rb").read()
if d[:3]==b"\xef\xbb\xbf": d=d[3:]; open(p,"wb").write(d); print("stripped BOM")
print("head:", d[:4].hex(" "), "size:", os.path.getsize(p))
assert d[:4]==b"\x7fELF"; print("ELF OK")
PYEOF
[ $? -ne 0 ] && exit 1

[ -f /usr/bin/dl_face.pre_prod ] || cp /usr/bin/dl_face /usr/bin/dl_face.pre_prod
systemctl stop dl-face
cp /tmp/dl_face.prod /usr/bin/dl_face
chmod +x /usr/bin/dl_face
systemctl reset-failed dl-face 2>/dev/null
systemctl start dl-face
echo "等待启动..."
sleep 34

echo
echo "=== 启动日志 ==="
journalctl -u dl-face --no-pager -n 12 -o cat 2>/dev/null | grep -E "注册|发现|屏点亮" | tail -n 5
echo "dl-face: $(systemctl is-active dl-face)"

echo
echo "=== 确认没有任何 AUX 自愈日志(应为空) ==="
journalctl -u dl-face --no-pager -n 30 -o cat 2>/dev/null | grep -E "掉线|回来了|数量变化|推帧连续失败" | tail -n 3
echo "(空 = 危险代码确实不在了 ✓)"

echo
echo "=== 稳定性 60 秒 ==="
R0=$(systemctl show -p NRestarts --value dl-face)
i=0
while [ $i -lt 6 ]; do
  sleep 10
  printf "  [%02ds] %-9s NRestarts=%s\n" "$(( (i+1)*10 ))" "$(systemctl is-active dl-face)" "$(systemctl show -p NRestarts --value dl-face)"
  i=$((i+1))
done
R1=$(systemctl show -p NRestarts --value dl-face)
[ "$R0" = "$R1" ] && echo "  ✅ 无重启" || echo "  ⚠️ 有重启"

echo
echo "=== 板上二进制 sha256(用于 manifest) ==="
sha256sum /usr/bin/dl_face | cut -d' ' -f1

echo
for s in astra-voice astra-mode astra-translate dl-face vision-wake; do
  printf "  %-18s %s\n" "$s" "$(systemctl is-active $s)"
done
