#!/bin/sh
echo "════ 板子状态 ════"
echo "  hostname: $(hostname)   开机: $(uptime | sed 's/.*up //; s/,.*load.*//')"
echo "  IP: $(ip -4 addr show eth0 2>/dev/null | grep -oE 'inet [0-9.]+' | cut -d' ' -f2)"
for s in astra-voice astra-translate dl-face vision-wake astra-mode; do
  printf "  %-18s %s\n" "$s" "$(systemctl is-active $s 2>/dev/null)"
done
echo "  屏幕: $(journalctl -u dl-face --no-pager -o cat -b 2>/dev/null | grep -c '屏点亮') 块点亮"

echo
echo "════ 当前系统版本(和镜像 TAG 对照) ════"
cat /etc/os-release 2>/dev/null | grep -E "VERSION|BUILD" | sed 's/^/  /'
ls /etc/version 2>/dev/null && cat /etc/version | sed 's/^/  /'
echo "  内核: $(uname -r)"

echo
echo "════ ★ 模型现状(这是唯一没有 PC 副本的东西) ════"
for d in sv matcha tts llm bin kws; do
  [ -d /home/voice/$d ] && printf "  %-8s %8s  %s 个文件\n" "$d/" "$(du -sh /home/voice/$d 2>/dev/null | cut -f1)" "$(find /home/voice/$d -type f | wc -l)"
done
echo "  合计: $(du -sh /home/voice 2>/dev/null | cut -f1)"

echo
echo "════ 磁盘空间(打包要地方) ════"
df -h / /home 2>/dev/null | sed 's/^/  /'
