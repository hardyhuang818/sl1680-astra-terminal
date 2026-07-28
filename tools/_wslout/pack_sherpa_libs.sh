#!/bin/bash
S=/home/astra/sdk/build-sl1680/tmp/work/cortexa73-poky-linux/sherpa-onnx
echo "=== sherpa 库产物 ==="
find $S -name "libsherpa-onnx-c-api.so*" -o -name "libonnxruntime.so*" 2>/dev/null | grep -v "\.debug" | head -n 6
D=$(find $S -path "*packages-split/sherpa-onnx/usr/lib" -type d 2>/dev/null | head -n 1)
[ -z "$D" ] && D=$(find $S -path "*image/usr/lib" -type d 2>/dev/null | head -n 1)
echo "库目录: $D"
ls -la "$D"/*.so* 2>/dev/null | head -n 10
echo
echo "=== 打包 ==="
O="/mnt/d/Claude code/Case6_Astra/SL1680_td7800_boot/sherpa_libs.tar.gz"
tar -czf "$O" -C "$D" $(cd "$D" && ls *.so* 2>/dev/null | tr '\n' ' ') 2>/dev/null
ls -la "$O"
tar -tzf "$O" | head -n 10
