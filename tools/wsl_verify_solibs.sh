#!/bin/bash
# 同步 sherpa recipe 并确认 .so 归属被改到运行时包
cp "/mnt/d/Claude code/Case6_Astra/meta-dlsdk/recipes-ai/sherpa-onnx/sherpa-onnx_1.13.4.bb" \
   /home/astra/sdk/meta-dlsdk/recipes-ai/sherpa-onnx/sherpa-onnx_1.13.4.bb
cd /home/astra/sdk
source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1
bitbake -e sherpa-onnx > /tmp/e_sherpa.txt 2>/tmp/e_sherpa.err
if [ $? -ne 0 ]; then
  echo "❌ 解析失败"; grep ERROR /tmp/e_sherpa.err | head -n 8; exit 1
fi
echo "✅ sherpa-onnx 解析通过"
echo
echo "════ SOLIBS / FILES_SOLIBSDEV ════"
grep -E '^(SOLIBS|FILES_SOLIBSDEV)=' /tmp/e_sherpa.txt
echo
echo "════ FILES:sherpa-onnx (运行时包，应含 .so) ════"
grep -E '^FILES:sherpa-onnx=' /tmp/e_sherpa.txt | tr ' ' '\n' | grep -E '\.so|lib' | head -n 8
echo
echo "════ FILES:sherpa-onnx-dev (不该再抢 .so) ════"
grep -E '^FILES:sherpa-onnx-dev=' /tmp/e_sherpa.txt | tr ' ' '\n' | grep -E '\.so' | head -n 6
echo "(上面若不含 libdir/lib*.so 就对了)"
