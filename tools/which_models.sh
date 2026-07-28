#!/bin/sh
echo "=== 云端对话模型(/etc/astra/llm.conf，key 打码) ==="
grep -E "^LLM_MODEL|^LLM_URL" /etc/astra/llm.conf 2>/dev/null | sed 's/^/  /'
for k in DEEPSEEK_API_KEY ZHIPU_API_KEY; do
  v=$(grep "^$k=" /etc/astra/llm.conf 2>/dev/null | cut -d= -f2)
  if [ -n "$v" ]; then printf "  %s = 已配置(%s…)\n" "$k" "$(echo "$v" | cut -c1-7)"; else printf "  %s = 未配置\n" "$k"; fi
done
echo
echo "=== astra_llm.py 默认值(llm.conf 没写时用哪个) ==="
grep -n 'LLM_MODEL"' /home/voice/astra_llm.py | sed 's/^/  /'
echo
echo "=== 翻译层用的模型 ==="
grep -n -E 'LLM_MODEL|MODEL|model' /home/voice/astra_translate.py 2>/dev/null | grep -i "environ\|getenv\|= *\"" | head -n 4 | sed 's/^/  /'
echo
echo "=== 本地兜底 LLM(断网时) ==="
systemctl show -p ExecStart --value astra-voice | tr ' ' '\n' | grep gguf | sed 's/^/  /'
echo
echo "=== ASR / TTS ==="
echo "  ASR : /home/voice/sv/model.int8.onnx  (SenseVoice int8)"
echo "  VAD : /home/voice/sv/silero_vad.onnx"
systemctl show -p ExecStart --value astra-voice | tr ' ' '\n' | grep -E "^matcha$|--tts" >/dev/null && echo "  TTS : matcha  (/home/voice/matcha/model-steps-3.onnx + vocos-16khz-univ.onnx)"
echo
echo "=== 视觉唤醒用的模型 ==="
grep -oE "synap_cli_od[^|]*" /usr/bin/vision_wake.sh 2>/dev/null | head -n 1 | sed 's/^/  /'
grep -oE "/[a-zA-Z0-9_/.-]*\.synap" /usr/bin/vision_wake.sh 2>/dev/null | head -n 2 | sed 's/^/  /'
echo
echo "=== 刚才那几句到底谁答的(看有没有走搜索层) ==="
journalctl -u astra-voice --no-pager -o cat 2>/dev/null | grep -E "^\[机器\]" | tail -n 3
journalctl -u astra-voice --no-pager -o cat 2>/dev/null | grep -cE "\[search\]" | sed 's/^/  搜索层调用次数: /'
