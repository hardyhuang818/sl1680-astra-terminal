#!/bin/sh
echo "════════ 重启后验收 ════════"
echo "  开机时长: $(uptime | sed 's/.*up //; s/,.*load.*//')"
echo

echo "──── 1. 屏幕 ────"
journalctl -u dl-face --no-pager -o cat -b 2>/dev/null | grep -E "热插拔|发现|屏点亮" | sed 's/^/  /'
echo "  dl-face: $(systemctl is-active dl-face)  NRestarts=$(systemctl show -p NRestarts --value dl-face)"
echo "  角色文件: $(cat /tmp/astra_screen_mode.txt 2>/dev/null | tr '\n' ' ')"
echo "  DL7400: $(lsusb 2>/dev/null | grep -c 17e9) 个"
echo

echo "──── 2. 服务自启 ────"
for s in astra-voice astra-translate dl-face vision-wake astra-mode astra-xiaozhi; do
  printf "  %-18s active=%-9s enabled=%s\n" "$s" "$(systemctl is-active $s 2>/dev/null)" "$(systemctl is-enabled $s 2>/dev/null)"
done
echo "  astra-voice NRestarts=$(systemctl show -p NRestarts --value astra-voice)"
echo

echo "──── 3. 音量(默认值是否持久) ────"
echo "  $(amixer -c dolphinasoc sget AstraVolume 2>/dev/null | grep -oE '\[[0-9]+%\]' | head -n 1)"
echo

echo "──── 4. 麦克风/摄像头 ────"
echo "  C920 音频: $(arecord -l 2>/dev/null | grep -c C920) (1=在)"
echo "  C920 视频: $(ls /dev/v4l/by-id/ 2>/dev/null | grep -c C920) (1=在)"
echo "  被谁占: $(for d in /dev/video*; do n=$(cat /sys/class/video4linux/$(basename $d)/name 2>/dev/null); case "$n" in *C920*|*Webcam*) h=$(fuser $d 2>/dev/null); [ -n "$h" ] && for p in $h; do cat /proc/$p/comm 2>/dev/null; done ;; esac; done | tr '\n' ' ')"
echo

echo "──── 5. 语音链路 ────"
journalctl -u astra-voice --no-pager -o cat -b 2>/dev/null | grep -E "模型就绪|开始监听|机器" | head -n 4 | sed 's/^/  /'
echo

echo "──── 6. 四层作答 ────"
. /etc/astra/llm.conf 2>/dev/null
export DEEPSEEK_API_KEY LLM_URL LLM_MODEL ZHIPU_API_KEY
printf '  音量层  "音量多少"     -> '; python3 /home/voice/astra_llm.py "音量多少"
printf '  设备层  "现在几点"     -> '; python3 /home/voice/astra_llm.py "现在几点"
printf '  云端层  "你是谁"       -> '; python3 /home/voice/astra_llm.py "你是谁"
printf '  搜索层  "广州天气"     -> '; python3 /home/voice/astra_llm.py "今天广州天气怎么样"
echo

echo "──── 7. 语音切摄像头(重启后仍可用?) ────"
printf '  "打开摄像头" -> '; python3 /home/voice/astra_llm.py "打开摄像头"
sleep 5
echo "  角色: $(cat /tmp/astra_screen_mode.txt 2>/dev/null | tr '\n' ' ')   vision-wake=$(systemctl is-active vision-wake)"
journalctl -u dl-face --no-pager -o cat -n 4 2>/dev/null | grep "切换角色" | tail -n 1 | sed 's/^/  /'
printf '  "关闭监控"   -> '; python3 /home/voice/astra_llm.py "关闭监控"
sleep 5
echo "  角色: $(cat /tmp/astra_screen_mode.txt 2>/dev/null | tr '\n' ' ')   vision-wake=$(systemctl is-active vision-wake)"
