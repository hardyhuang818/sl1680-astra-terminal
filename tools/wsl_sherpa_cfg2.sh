#!/bin/bash
cp "/mnt/d/Claude code/Case6_Astra/meta-dlsdk/recipes-ai/sherpa-onnx/sherpa-onnx_1.13.4.bb" \
   /home/astra/sdk/meta-dlsdk/recipes-ai/sherpa-onnx/sherpa-onnx_1.13.4.bb
cd /home/astra/sdk
set +e
source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1
W=build-sl1680/tmp/work/cortexa73-poky-linux/sherpa-onnx/1.13.4

echo "════ 重跑 do_configure ════"
bitbake -c configure sherpa-onnx > /tmp/cf2.txt 2>&1
RC=$?
L=$(ls -t $W/temp/log.do_configure.* 2>/dev/null | head -n 1)

if [ $RC -eq 0 ]; then
  echo "  ✅✅ configure 通过"
else
  echo "  ❌ rc=$RC"
  grep -A5 "CMake Error" "$L" 2>/dev/null | head -n 16 | sed 's/^/    /'
fi

echo
echo "════ 关键证据：每个包都命中本地了吗(不能有联网) ════"
grep -E "Found local downloaded|^-- Downloading" "$L" 2>/dev/null | sed 's|/home/astra/sdk/build-sl1680/tmp/work/cortexa73-poky-linux/sherpa-onnx/1.13.4|<W>|g' | sed 's/^/  /'

echo
echo "════ 有没有偷偷连网(出现 https:// 就是没命中本地) ════"
n=$(grep -cE "^-- Downloading.*https://" "$L" 2>/dev/null)
echo "  联网下载次数: $n  (必须为 0)"

echo
echo "════ _deps 里解出来的源码 ════"
ls $W/build/_deps 2>/dev/null | grep -- "-src$" | sed 's/^/  /'
