#!/bin/bash
D=/home/astra/sdk/build-sl1680/tmp/deploy/deb
echo "════ sherpa-onnx 运行时 deb 里的 /usr/lib 内容 ════"
p=$(find $D -name "sherpa-onnx_1.13.4*.deb" | head -n 1)
dpkg -c "$p" 2>/dev/null | grep "/usr/lib" | awk '{printf "  %11s  %s\n",$3,$6}'
echo
echo "  该包总条目数: $(dpkg -c "$p" 2>/dev/null | wc -l)"
echo "  其中 .so 文件: $(dpkg -c "$p" 2>/dev/null | grep -c '\.so')"

echo
echo "════ 对照：-dev 包里有没有抢走 .so ════"
p=$(find $D -name "sherpa-onnx-dev_*.deb" | head -n 1)
echo "  $(basename $p)"
dpkg -c "$p" 2>/dev/null | grep -E "\.so$" | awk '{printf "    %11s  %s\n",$3,$6}'
echo "    (空 = 没抢，SOLIBS 修复生效 ✓)"

echo
echo "════ 结论 ════"
p=$(find $D -name "sherpa-onnx_1.13.4*.deb" | head -n 1)
n=$(dpkg -c "$p" 2>/dev/null | grep -c "libsherpa-onnx-c-api.so")
m=$(dpkg -c "$p" 2>/dev/null | grep -c "libonnxruntime.so")
if [ "$n" -ge 1 ] && [ "$m" -ge 1 ]; then
  echo "  ✅ 运行时包里 libsherpa-onnx-c-api.so 和 libonnxruntime.so 都在 —— 烧板后 astra_voice 能起来"
else
  echo "  ❌ 缺库: c-api=$n onnxruntime=$m —— 烧板后会 cannot open shared object file"
fi
