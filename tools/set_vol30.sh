#!/bin/sh
set -u
echo "=== 改前 ==="
grep -o "astra_setvol.sh [0-9]*%" /etc/systemd/system/astra-voice.service /etc/systemd/system/astra-xiaozhi.service 2>/dev/null
echo -n "当前音量: "; amixer -c dolphinasoc sget AstraVolume 2>/dev/null | grep -oE "\[[0-9]+%\]" | head -n 1

echo
echo "=== 开机默认 10% -> 30% (两个服务都改) ==="
sed -i "s/astra_setvol.sh 10%/astra_setvol.sh 30%/" /etc/systemd/system/astra-voice.service
sed -i "s/astra_setvol.sh 10%/astra_setvol.sh 30%/" /etc/systemd/system/astra-xiaozhi.service 2>/dev/null
grep -o "astra_setvol.sh [0-9]*%" /etc/systemd/system/astra-voice.service /etc/systemd/system/astra-xiaozhi.service 2>/dev/null
systemctl daemon-reload

echo
echo "=== 立即生效(不用等重启) ==="
amixer -c dolphinasoc sset AstraVolume 30% >/dev/null 2>&1
echo -n "现在音量: "; amixer -c dolphinasoc sget AstraVolume 2>/dev/null | grep -oE "\[[0-9]+%\]" | head -n 1

echo
echo "=== 验证语音查询能读到新值 ==="
. /etc/astra/llm.conf
export DEEPSEEK_API_KEY LLM_MODEL LLM_URL ZHIPU_API_KEY
cd /home/voice
printf "  问[现在音量多少] -> "; python3 astra_llm.py "现在音量多少" 2>&1 | head -n 1

echo
echo "=== 服务状态(没动服务, 应全部照常) ==="
for s in astra-voice astra-mode astra-translate dl-face vision-wake; do
  printf "  %-18s %s\n" "$s" "$(systemctl is-active $s)"
done
