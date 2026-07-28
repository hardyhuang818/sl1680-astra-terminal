#!/bin/sh
echo "════════ 0. 基本状态 ════════"
echo "  开机时长: $(uptime | sed 's/.*up //; s/,.*load.*//')"
echo "  负载: $(uptime | sed 's/.*load average: //')"
for s in astra-voice astra-translate dl-face vision-wake astra-mode astra-xiaozhi; do
  printf "  %-18s active=%-9s enabled=%s\n" "$s" "$(systemctl is-active $s 2>/dev/null)" "$(systemctl is-enabled $s 2>/dev/null)"
done

echo
echo "════════ 1. 屏幕 ════════"
echo "  DL7400: $(lsusb 2>/dev/null | grep -i 17e9 | sed 's/.*ID /ID /')"
echo "  dl_face 本次启动枚举到的屏:"
journalctl -u dl-face --no-pager -o cat --since "-6 hours" 2>/dev/null | grep -E "发现|屏点亮" | tail -n 5 | sed 's/^/    /'
echo "  当前角色文件:"
cat /tmp/astra_screen_mode.txt 2>/dev/null | sed 's/^/    /' || echo "    (不存在)"
echo "  dl-face NRestarts=$(systemctl show -p NRestarts --value dl-face)"

echo
echo "════════ 2a. 语音控制音量 ════════"
. /etc/astra/llm.conf 2>/dev/null
export DEEPSEEK_API_KEY LLM_URL LLM_MODEL ZHIPU_API_KEY
echo "  改前: $(amixer -c dolphinasoc sget AstraVolume 2>/dev/null | grep -oE '\[[0-9]+%\]' | head -n 1)"
printf '  问"音量多少"      -> '; python3 /home/voice/astra_llm.py "音量多少"
printf '  说"音量调到20%%"   -> '; python3 /home/voice/astra_llm.py "音量调到20%"
echo "  实际值: $(amixer -c dolphinasoc sget AstraVolume 2>/dev/null | grep -oE '\[[0-9]+%\]' | head -n 1)"
printf '  说"音量调到30%%"   -> '; python3 /home/voice/astra_llm.py "音量调到30%"
echo "  复原后: $(amixer -c dolphinasoc sget AstraVolume 2>/dev/null | grep -oE '\[[0-9]+%\]' | head -n 1)"

echo
echo "════════ 2b. 语音切摄像头 ════════"
printf '  说"打开摄像头"    -> '; python3 /home/voice/astra_llm.py "打开摄像头"
sleep 4
echo "  角色文件: $(cat /tmp/astra_screen_mode.txt 2>/dev/null | tr '\n' ' ')"
echo "  vision-wake: $(systemctl is-active vision-wake)  (切摄像头时应被停掉)"
echo "  dl-face 日志:"
journalctl -u dl-face --no-pager -o cat -n 6 2>/dev/null | grep "切换角色" | tail -n 2 | sed 's/^/    /'
echo "  摄像头被谁占:"
for d in /dev/video*; do
  n=$(cat /sys/class/video4linux/$(basename "$d")/name 2>/dev/null)
  case "$n" in *C920*|*Webcam*)
    h=$(fuser "$d" 2>/dev/null)
    [ -n "$h" ] && { printf "    %s -> " "$d"; for p in $h; do cat /proc/$p/comm 2>/dev/null | tr '\n' ' '; done; echo; }
  ;; esac
done

echo
printf '  说"关闭监控"      -> '; python3 /home/voice/astra_llm.py "关闭监控"
sleep 4
echo "  角色文件: $(cat /tmp/astra_screen_mode.txt 2>/dev/null | tr '\n' ' ')"
echo "  vision-wake: $(systemctl is-active vision-wake)  (应恢复)"

echo
echo "════════ 3. 语音对话 ════════"
printf '  本地设备层"现在几点"  -> '; python3 /home/voice/astra_llm.py "现在几点"
printf '  云端对话"你是谁"      -> '; python3 /home/voice/astra_llm.py "你是谁"
printf '  联网搜索"今天广州天气" -> '; python3 /home/voice/astra_llm.py "今天广州天气怎么样"
echo
echo "  最近真实语音往返(证明 麦→ASR→回复→TTS 全链路活着):"
journalctl -u astra-voice --no-pager -o cat --since "-2 hours" 2>/dev/null | grep -E "^\[你 \]|^\[机器\]" | tail -n 6 | sed 's/^/    /'
echo
echo "  本次开机累计: 识别 $(journalctl -u astra-voice --no-pager -o cat 2>/dev/null | grep -c '^\[你 \]') 次, 视觉唤醒 $(journalctl -u astra-voice --no-pager -o cat 2>/dev/null | grep -c '检测到有人靠近') 次"
