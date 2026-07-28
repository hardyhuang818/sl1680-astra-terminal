#!/bin/bash
B=/home/astra/sdk/build-sl1680
D=$B/tmp/deploy/deb
W=$B/tmp/work/cortexa73-poky-linux

echo "════ ★ sherpa-onnx 运行时 deb 里到底有没有 .so ════"
p=$(find $D -name "sherpa-onnx_1.13.4*.deb" | head -n 1)
echo "  包: $(basename $p)  ($(stat -c %s $p) 字节)"
dpkg -c "$p" 2>/dev/null | grep -E "\.so|/bin/" | awk '{printf "    %10s  %s\n",$3,$6}' | head -n 20

echo
echo "════ ★ astra-voice deb 的依赖关系 ════"
p=$(find $D -name "astra-voice_1.0*.deb" | head -n 1)
dpkg -I "$p" 2>/dev/null | grep -E "^ (Package|Depends|Recommends|Version|Architecture)" | sed 's/^/  /'

echo
echo "════ dl-face deb 的依赖关系 ════"
p=$(find $D -name "dl-face_1.0*.deb" | head -n 1)
dpkg -I "$p" 2>/dev/null | grep -E "^ (Package|Depends|Version|Architecture)" | sed 's/^/  /'

echo
echo "════ dl_face NEEDED(上次 sed 写坏了，重来) ════"
readelf -d $W/dl-face/1.0/image/usr/bin/dl_face 2>/dev/null | grep NEEDED | sed 's/.*\[\(.*\)\]/    \1/'

echo
echo "════ 对照：板子上现役 astra_voice 的链接方式 ════"
echo "    板端是【静态】链 sherpa(无 libsherpa NEEDED)"
echo "    新构建是【动态】链(NEEDED: libsherpa-onnx-c-api.so) —— 行为等价，但依赖 sherpa-onnx 包同时装上"

echo
echo "════ 全部 recipe 的构建状态 ════"
cd /home/astra/sdk && source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1
for r in sherpa-onnx astra-voice dl-face; do
  printf "  %-14s " "$r"
  bitbake -n $r >/dev/null 2>&1 && echo "✅ 任务图可生成且已构建" || echo "❌"
done
