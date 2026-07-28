#!/bin/sh
echo "=== /home/voice 结构(模型根) ==="
ls /home/voice | sed 's/^/  /'
echo
for d in sv matcha tts bin; do
  printf "/home/voice/%s:\n" "$d"
  ls -l /home/voice/$d 2>/dev/null | awk 'NR>0{printf "    %10s  %s\n",$5,$9}' | head -n 8
done
echo
echo "=== 模型总大小(决定要不要打进 recipe) ==="
du -sh /home/voice/sv /home/voice/matcha /home/voice/tts /home/voice/llm 2>/dev/null | sed 's/^/  /'
echo
echo "=== 字体归属包 ==="
opkg search /usr/share/fonts/ttf/wqy-zenhei.ttf 2>/dev/null | sed 's/^/  /'
opkg list-installed 2>/dev/null | grep -i -E "wqy|zenhei" | sed 's/^/  /'
echo
echo "=== dl_face 用的字体名 ==="
strings /usr/bin/dl_face 2>/dev/null | grep -i "WenQuanYi\|Zen Hei" | sed 's/^/  /' | head -n 3
