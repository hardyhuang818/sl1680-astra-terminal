#!/bin/bash
W=/home/astra/sdk/build-sl1680/tmp/work/cortexa73-poky-linux/sherpa-onnx/1.13.4/temp
L=$(ls -t $W/log.do_configure.* 2>/dev/null | head -n 1)
echo "日志: ${L##*/}"
echo
echo "════ 真正的报错 ════"
grep -iE "CMake Error|error:|fatal|Could NOT find|failed|Downloading|curl|wget|onnxruntime" "$L" 2>/dev/null | grep -v "Werror=format-security" | head -n 25 | sed 's/^/  /'
