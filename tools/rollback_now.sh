#!/bin/sh
echo "════════ 紧急回滚 ════════"
echo "回滚前 dl-face 日志(留证据):"
journalctl -u dl-face --no-pager -n 25 -o cat 2>/dev/null | tail -n 18

echo
echo "=== 回滚到 dpaux 补丁之前的版本 ==="
systemctl stop dl-face
sleep 2
if [ -f /usr/bin/dl_face.pre_dpaux ]; then
  cp /usr/bin/dl_face.pre_dpaux /usr/bin/dl_face
  echo "  已还原 dl_face.pre_dpaux"
elif [ -f /usr/bin/dl_face.pre_selfheal ]; then
  cp /usr/bin/dl_face.pre_selfheal /usr/bin/dl_face
  echo "  已还原 dl_face.pre_selfheal"
else
  cp /usr/bin/dl_face.bak /usr/bin/dl_face
  echo "  已还原 dl_face.bak(最早的单语版)"
fi
chmod +x /usr/bin/dl_face
ls -l /usr/bin/dl_face

echo
echo "=== 顺便把屏1 从 camera 模式复位成表情脸 ==="
printf '0=face\n1=face\n' > /tmp/astra_screen_mode.txt

systemctl reset-failed dl-face 2>/dev/null
systemctl start dl-face
echo "等待重新枚举点亮(20秒延迟+枚举)..."
sleep 36

echo
echo "════════ 回滚后状态 ════════"
journalctl -u dl-face --no-pager -n 12 -o cat 2>/dev/null | grep -E "发现|屏点亮|失败" | tail -n 5
echo "dl-face: $(systemctl is-active dl-face)"
echo "点亮屏数: $(journalctl -u dl-face --no-pager -n 20 -o cat 2>/dev/null | grep -c '屏点亮')"

echo
systemctl start vision-wake 2>/dev/null
sleep 3
for s in astra-voice astra-mode astra-translate dl-face vision-wake; do
  printf "  %-18s %s\n" "$s" "$(systemctl is-active $s)"
done
