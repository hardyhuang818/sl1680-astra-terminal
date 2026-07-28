#!/bin/bash
B=/home/astra/sdk/build-sl1680/tmp/work/cortexa73-poky-linux/astra-voice/1.0/packages-split/astra-voice/usr/bin/astra_voice
D="/mnt/d/Claude code/Case6_Astra/SL1680_td7800_boot/astra_voice_v28"
ls -la "$B"
echo "=== 验证旧规则已消失 ==="
if grep -aq "没有联网，查不到实时天气" "$B"; then
  echo "  ✗ 旧规则仍在二进制里!"; exit 1
else
  echo "  √ 旧的天气拦截规则已删除"
fi
echo "=== 验证仍保留时间/日期规则 ==="
grep -aq "今天是星期" "$B" && echo "  √ 星期规则在" || echo "  ✗ 星期规则丢了?"
grep -aq "astra_llm.py" "$B" && echo "  √ 云端调用点在" || echo "  ✗ 云端调用点丢了?"
cp "$B" "$D"
sha256sum "$D" | cut -c1-72
ls -la "$D"
