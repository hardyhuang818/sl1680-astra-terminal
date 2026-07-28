#!/bin/sh
set -u
python3 - <<'PYEOF'
import os
p="/tmp/dl_face.dpaux"; d=open(p,"rb").read()
if d[:3]==b"\xef\xbb\xbf": d=d[3:]; open(p,"wb").write(d); print("stripped BOM")
print("head:", d[:4].hex(" "), "size:", os.path.getsize(p))
assert d[:4]==b"\x7fELF", "not ELF!"
print("ELF OK")
PYEOF
[ $? -ne 0 ] && { echo "ABORT"; exit 1; }

[ -f /usr/bin/dl_face.pre_dpaux ] || cp /usr/bin/dl_face /usr/bin/dl_face.pre_dpaux
systemctl stop dl-face
cp /tmp/dl_face.dpaux /usr/bin/dl_face
chmod +x /usr/bin/dl_face
systemctl reset-failed dl-face 2>/dev/null
systemctl start dl-face
echo "等待启动(20秒 ExecStartPre + 枚举)..."
sleep 34

echo
echo "=== 启动情况 ==="
journalctl -u dl-face --no-pager -n 15 -o cat 2>/dev/null | grep -E "注册|发现|屏点亮|掉线|回来了" | tail -n 5
echo "dl-face: $(systemctl is-active dl-face)"

echo
echo "════════ 盯 90 秒(覆盖 9 次 AUX 探测) ════════"
R0=$(systemctl show -p NRestarts --value dl-face)
i=0
while [ $i -lt 9 ]; do
  sleep 10
  printf "  [%02ds] %-9s NRestarts=%s\n" "$(( (i+1)*10 ))" "$(systemctl is-active dl-face)" "$(systemctl show -p NRestarts --value dl-face)"
  i=$((i+1))
done
R1=$(systemctl show -p NRestarts --value dl-face)

echo
echo "=== AUX 探测有没有误报(两块屏都在, 应该安静) ==="
journalctl -u dl-face --no-pager -n 40 -o cat 2>/dev/null | grep -E "掉线|回来了" | tail -n 5
echo "(空 = 没误报 ✓)"

echo
echo "════════ 判定 ════════"
if [ "$(systemctl is-active dl-face)" = "active" ] && [ "$R0" = "$R1" ]; then
  echo "  ✅ 部署成功: 稳定运行、无重启、AUX 探测无误报"
else
  echo "  ❌ 异常 -> 回滚"
  systemctl stop dl-face
  cp /usr/bin/dl_face.pre_dpaux /usr/bin/dl_face
  chmod +x /usr/bin/dl_face
  systemctl start dl-face
  sleep 32
  echo "  回滚后: $(systemctl is-active dl-face)"
fi
echo
for s in astra-voice astra-mode astra-translate dl-face vision-wake; do
  printf "  %-18s %s\n" "$s" "$(systemctl is-active $s)"
done
