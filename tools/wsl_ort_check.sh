#!/bin/bash
W=/home/astra/sdk/build-sl1680/tmp/work/cortexa73-poky-linux/sherpa-onnx/1.13.4
echo "════ image/usr/lib 里到底装了什么 ════"
ls -l $W/image/usr/lib/ 2>/dev/null | awk 'NR>1{printf "  %11s  %s\n",$5,$9}'
echo
echo "════ 预编译 onnxruntime 解压在哪、有哪些 .so ════"
ls -l $W/build/_deps/onnxruntime-src/lib/ 2>/dev/null | awk 'NR>1{printf "  %11s  %s\n",$5,$9}'
echo
echo "════ libsherpa-onnx-c-api.so 的 NEEDED ════"
readelf -d $W/image/usr/lib/libsherpa-onnx-c-api.so 2>/dev/null | grep NEEDED | sed 's/.*\[\(.*\)\]/  \1/'
echo
echo "════ RPATH/RUNPATH(能不能自己找到 onnxruntime) ════"
readelf -d $W/image/usr/lib/libsherpa-onnx-c-api.so 2>/dev/null | grep -E "RPATH|RUNPATH" | sed 's/^/  /'
echo "  (空 = 没有，必须靠 /usr/lib 里真有这个库)"
echo
echo "════ 板子上现在那份 astra_voice 是怎么解决的 ════"
echo "  (板端 astra_voice 是静态链接 sherpa 的，所以没有这个问题)"
