#!/bin/bash
S=/home/astra/sdk/build-sl1680/tmp/work/cortexa73-poky-linux/sherpa-onnx/1.13.4/git
echo "════ c-api/CMakeLists.txt 全文 ════"
cat $S/sherpa-onnx/c-api/CMakeLists.txt
echo
echo "════ 全项目里有没有设 SOVERSION ════"
grep -rn "SOVERSION\|set_target_properties.*VERSION" $S/CMakeLists.txt $S/sherpa-onnx/csrc/CMakeLists.txt $S/sherpa-onnx/c-api/CMakeLists.txt 2>/dev/null | head -n 8
echo "(无输出 = 生成的是无版本号的 libXXX.so)"
