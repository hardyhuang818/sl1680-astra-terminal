#!/bin/bash
S=/home/astra/sdk/build-sl1680/tmp/work/cortexa73-poky-linux/sherpa-onnx/1.13.4/git
echo "════ c-api 的库目标名(决定 -l 写什么) ════"
grep -rn "add_library" $S/sherpa-onnx/c-api/CMakeLists.txt 2>/dev/null | sed 's/^/  /'
echo
echo "════ install 规则(决定装到哪、叫什么) ════"
grep -n -A6 "^install" $S/sherpa-onnx/c-api/CMakeLists.txt 2>/dev/null | head -n 20
echo
echo "════ 头文件安装位置 ════"
grep -rn "c-api.h" $S/sherpa-onnx/c-api/CMakeLists.txt 2>/dev/null | sed 's/^/  /'
echo
echo "════ 顶层 CMake 里 C_API 开关下建了什么 ════"
grep -n -B2 -A8 "SHERPA_ONNX_ENABLE_C_API" $S/CMakeLists.txt 2>/dev/null | head -n 25
