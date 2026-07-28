#!/bin/sh
echo "=== /home/voice/kws 里有什么 ==="
ls -l /home/voice/kws 2>/dev/null | awk 'NR>1{printf "  %10s  %s\n",$5,$9}'
echo
echo "=== 关键词检测器帮助(看要哪些参数) ==="
/home/voice/bin/sherpa-onnx-keyword-spotter-alsa --help 2>&1 | grep -iE "keywords|tokens|encoder|decoder|joiner|Usage|device" | head -n 14 | sed 's/^/  /'
echo
echo "=== 关键词文件长什么样 ==="
for f in /home/voice/kws/keywords.txt /home/voice/kws/keywords_raw.txt /home/voice/kws/*.txt; do
  [ -f "$f" ] || continue
  echo "  --- $f"
  head -n 6 "$f" | sed 's/^/     /'
  break
done
echo
echo "=== 之前试过 KWS 吗(有没有留下脚本/日志) ==="
ls /home/voice/*kws* /home/voice/*wake* 2>/dev/null | sed 's/^/  /'
echo
echo "=== 现在 mic 音量 / 能不能单独静音 ==="
amixer -c C920 sget Mic 2>/dev/null | grep -E "Capture|Limits|\[" | head -n 4 | sed 's/^/  /'
