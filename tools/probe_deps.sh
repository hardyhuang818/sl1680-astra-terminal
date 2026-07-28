#!/bin/sh
echo "=== astra_voice NEEDED ==="
readelf -d /usr/bin/astra_voice 2>/dev/null | grep NEEDED | sed 's/.*\[\(.*\)\]/  \1/'
echo
echo "=== dl_face NEEDED ==="
readelf -d /usr/bin/dl_face 2>/dev/null | grep NEEDED | sed 's/.*\[\(.*\)\]/  \1/'
echo
echo "=== 模型/资源实际路径 ==="
for d in /home/voice/models /home/voice/llm /etc/astra; do
  printf "%s:\n" "$d"; ls "$d" 2>/dev/null | sed 's/^/    /' | head -n 12
done
echo
echo "=== 中文字体在哪 ==="
find /usr/share/fonts -name "*.tt[cf]" 2>/dev/null | sed 's/^/  /' | head -n 8
echo
echo "=== dl_face 里写死的字体路径 ==="
strings /usr/bin/dl_face 2>/dev/null | grep -i "\.tt[cf]" | sed 's/^/  /' | head -n 4
echo
echo "=== astra_voice 里写死的模型路径 ==="
strings /usr/bin/astra_voice 2>/dev/null | grep -E "^/home/voice/|\.onnx$" | sed 's/^/  /' | head -n 12
