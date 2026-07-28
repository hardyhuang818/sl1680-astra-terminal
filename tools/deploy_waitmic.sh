#!/bin/sh
set -u
# busybox 没有 install(1)，用 cp + chmod。
# 每一步都验证，不做无条件的"已装"回显。

for f in /tmp/astra_wait_mic.sh /tmp/astra-voice.service; do
  python3 - "$f" <<'PY'
import sys
p=sys.argv[1]; d=open(p,"rb").read()
if d[:3]==b"\xef\xbb\xbf":
    open(p,"wb").write(d[3:]); print("  剥掉 BOM:", p)
PY
done

echo "════ 部署 ════"
[ -f /etc/systemd/system/astra-voice.service.pre_waitmic ] || \
  cp /etc/systemd/system/astra-voice.service /etc/systemd/system/astra-voice.service.pre_waitmic

cp /tmp/astra_wait_mic.sh /usr/bin/astra_wait_mic.sh && chmod 0755 /usr/bin/astra_wait_mic.sh
if [ -x /usr/bin/astra_wait_mic.sh ]; then
  echo "  ✓ /usr/bin/astra_wait_mic.sh  ($(stat -c %s /usr/bin/astra_wait_mic.sh) 字节, 可执行)"
else
  echo "  ✗ astra_wait_mic.sh 装失败"; exit 1
fi

cp /tmp/astra-voice.service /etc/systemd/system/astra-voice.service && chmod 0644 /etc/systemd/system/astra-voice.service
grep -q "astra_wait_mic.sh" /etc/systemd/system/astra-voice.service \
  && echo "  ✓ astra-voice.service 含 wait_mic (旧版备份 .pre_waitmic)" \
  || { echo "  ✗ service 没写进去"; exit 1; }
systemctl daemon-reload

echo
echo "════ systemd 真的认了吗 ════"
systemctl show astra-voice -p StartLimitIntervalUSec -p StartLimitBurst -p TimeoutStartUSec | sed 's/^/  /'
echo "  ExecStartPre 顺序(wait_mic 必须排第一):"
systemctl show astra-voice -p ExecStartPre --value | tr ';' '\n' | grep -o 'path=[^ ]*' | sed 's/path=/    /'

echo
echo "════ 自测 1: 麦克风在 → 应约 2 秒返回 0 ════"
T0=$(date +%s)
/usr/bin/astra_wait_mic.sh C920 10
echo "  退出码=$? 耗时=$(( $(date +%s) - T0 ))s"

echo
echo "════ 自测 2: 卡名不存在 → 应等满 5 秒且退出码仍为 0 ════"
T0=$(date +%s)
/usr/bin/astra_wait_mic.sh NOSUCHCARD 5
echo "  退出码=$? 耗时=$(( $(date +%s) - T0 ))s"

echo
echo "════ 重启服务确认没搞坏 ════"
systemctl restart astra-voice
sleep 24
echo "  astra-voice: $(systemctl is-active astra-voice)  NRestarts=$(systemctl show -p NRestarts --value astra-voice)"
journalctl -u astra-voice --no-pager -o cat -n 6 2>/dev/null | tail -n 3 | sed 's/^/    /'
