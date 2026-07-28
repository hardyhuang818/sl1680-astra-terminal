#!/bin/bash
W=/home/astra/sdk/build-sl1680/tmp/work/cortexa73-poky-linux/sherpa-onnx/1.13.4
L=$(ls -t $W/temp/log.do_compile.[0-9]* 2>/dev/null | head -n 1)
echo "日志: ${L##*/}  ($(wc -l < "$L") 行)"
echo
echo "════ 真正的编译错误 ════"
grep -nE "error:|Error [0-9]|fatal error|undefined reference|No such file or directory|ninja: build stopped" "$L" 2>/dev/null | head -n 25 | sed "s|$W|<W>|g" | sed 's/^/  /'
echo
echo "════ 尾部 25 行 ════"
tail -n 25 "$L" 2>/dev/null | cut -c1-220 | sed "s|$W|<W>|g" | sed 's/^/  /'
