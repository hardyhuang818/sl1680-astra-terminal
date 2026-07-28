#!/bin/bash
# 完整构建 sherpa-onnx：compile + install + package
O="/mnt/d/Claude code/Case6_Astra/tools/_wslout"
mkdir -p "$O"

# ★ 必须先同步 recipe —— 之前漏了这步，白跑了一轮完整编译
cp "/mnt/d/Claude code/Case6_Astra/meta-dlsdk/recipes-ai/sherpa-onnx/sherpa-onnx_1.13.4.bb"    /home/astra/sdk/meta-dlsdk/recipes-ai/sherpa-onnx/sherpa-onnx_1.13.4.bb

cd /home/astra/sdk
set +e
source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1
W=/home/astra/sdk/build-sl1680/tmp/work/cortexa73-poky-linux/sherpa-onnx/1.13.4

echo "开始: $(date '+%H:%M:%S')" > "$O/build.log"
bitbake sherpa-onnx >> "$O/build.log" 2>&1
RC=$?
echo "结束: $(date '+%H:%M:%S')  rc=$RC" >> "$O/build.log"

{
  echo "════════ 结果 ════════"
  echo "SECURITY_STRINGFORMAT 实际生效值:"
  bitbake -e sherpa-onnx 2>/dev/null | grep -E "^SECURITY_STRINGFORMAT=" | sed "s/^/  /"
  if [ $RC -eq 0 ]; then echo "✅✅✅ bitbake sherpa-onnx 全绿"; else echo "❌ rc=$RC"; fi
  echo
  echo "── 错误 ──"
  grep -E "^ERROR" "$O/build.log" | head -n 10
  echo
  echo "── 产出的库 ──"
  ls -l $W/image/usr/lib/libsherpa*.so 2>/dev/null | awk '{printf "  %10s  %s\n",$5,$9}'
  echo "── 产出的可执行 ──"
  ls $W/image/usr/bin/ 2>/dev/null | head -n 12 | sed 's/^/  /'
  echo
  echo "── ★关键：.so 进了运行时包还是 -dev 包 ──"
  for p in sherpa-onnx sherpa-onnx-dev; do
    d=$W/packages-split/$p/usr/lib
    n=$(ls $d/libsherpa*.so 2>/dev/null | wc -l)
    printf "  %-18s %s 个 .so\n" "$p" "$n"
    ls $d/libsherpa*.so 2>/dev/null | sed 's|.*/|      |'
  done
  echo
  echo "── deb 包 ──"
  find build-sl1680/tmp/deploy/deb -name "sherpa-onnx*" 2>/dev/null | sed 's|.*/|  |' | head -n 8
  echo
  echo "── 架构确认 ──"
  f=$(ls $W/image/usr/lib/libsherpa-onnx-c-api.so 2>/dev/null | head -n 1)
  [ -n "$f" ] && file "$f" | sed 's/^/  /'
} > "$O/result.txt" 2>&1
cat "$O/result.txt"
