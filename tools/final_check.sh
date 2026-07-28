#!/bin/sh
echo "════ 五个服务 ════"
for s in astra-voice astra-mode astra-translate dl-face vision-wake; do
  printf "  %-18s %-9s %s\n" "$s" "$(systemctl is-active $s)" "$(systemctl is-enabled $s)"
done
echo
echo "════ 音量 ════"
amixer -c dolphinasoc sget AstraVolume 2>/dev/null | grep -oE '\[[0-9]+%\]' | head -n 1
echo
echo "════ dl-face 稳定性 ════"
echo "  NRestarts=$(systemctl show -p NRestarts --value dl-face)"
journalctl -u dl-face --no-pager -n 20 -o cat 2>/dev/null | grep -E "注册|发现" | tail -n 2
echo "  AUX 自愈日志(应为空): $(journalctl -u dl-face --no-pager -n 50 -o cat 2>/dev/null | grep -cE '掉线|回来了|数量变化')"
echo
echo "════ astra_llm.py 现役版本 ════"
sha256sum /home/voice/astra_llm.py | cut -d' ' -f1
python3 -c "import ast,sys; ast.parse(open('/home/voice/astra_llm.py',encoding='utf-8').read()); print('  语法 OK')"
echo
echo "════ 最后一次对话 ════"
journalctl -u astra-voice --no-pager -n 60 -o cat 2>/dev/null | grep -E "^\[你|^\[机器" | tail -n 4
