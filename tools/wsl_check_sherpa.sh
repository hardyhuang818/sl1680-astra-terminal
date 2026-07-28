#!/bin/bash
cd /home/astra/sdk
W=build-sl1680/tmp/work
echo "════ sherpa-onnx 构建过没 ════"
ls -d $W/cortexa73-poky-linux/sherpa-onnx/*/ 2>/dev/null | head -n 3 || echo "  没构建过"
echo
echo "════ sysroot 里的 sherpa 库 ════"
find $W/cortexa73-poky-linux/sherpa-onnx/*/image/usr/lib -maxdepth 1 -name 'libsherpa*' 2>/dev/null | sed 's|.*/|  |' | head -n 12
echo
echo "════ sysroot 里的 c-api 头 ════"
find $W/cortexa73-poky-linux/sherpa-onnx/*/image/usr/include -path '*c-api*' 2>/dev/null | sed 's|.*/include/|  |' | head -n 6
echo
echo "════ 共享 sysroot(recipe-sysroot) 里有没有 ════"
find $W/cortexa73-poky-linux -maxdepth 6 -name 'libsherpa-onnx-c-api*' 2>/dev/null | head -n 4
find $W/cortexa73-poky-linux -maxdepth 8 -path '*sherpa-onnx/c-api/c-api.h' 2>/dev/null | head -n 3
