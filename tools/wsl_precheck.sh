#!/bin/bash
P=/home/astra/sdk/poky
S=/home/astra/sdk/build-sl1680/tmp/work/cortexa73-poky-linux/sherpa-onnx/1.13.4/git

echo "════ Yocto 版本(决定用 WORKDIR 还是 UNPACKDIR) ════"
grep -E "^DISTRO_VERSION|^DISTRO_CODENAME" $P/meta-poky/conf/distro/poky.conf 2>/dev/null | sed 's/^/  /'
grep -rn "^UNPACKDIR" $P/meta/conf/bitbake.conf 2>/dev/null | sed 's/^/  /'
echo "  (没有 UNPACKDIR = 用 WORKDIR)"

echo
echo "════ openfst 在什么条件下被 include ════"
grep -n "openfst\|hclust\|eigen" $S/CMakeLists.txt | sed 's/^/  /'

echo
echo "════ SPEAKER_DIARIZATION 关掉能省掉什么 ════"
sed -n '/if(SHERPA_ONNX_ENABLE_SPEAKER_DIARIZATION)/,/endif/p' $S/CMakeLists.txt | sed 's/^/  /'

echo
echo "════ TTS 开关下拉哪些(我们必须要 TTS) ════"
sed -n '/if(SHERPA_ONNX_ENABLE_TTS)/,/endif/p' $S/CMakeLists.txt | sed 's/^/  /'

echo
echo "════ eigen 的 URL(gitlab 不是 github) ════"
grep -oE 'https://[^"$)]*eigen[^"$)]*' $S/cmake/eigen.cmake 2>/dev/null | head -n 2 | sed 's/^/  /'
grep -oE '\$\{CMAKE_SOURCE_DIR\}/[^ ]*' $S/cmake/eigen.cmake 2>/dev/null | head -n 1 | sed 's|.*/|   期望文件名: |'
grep -oE '\$\{CMAKE_SOURCE_DIR\}/[^ ]*' $S/cmake/hclust-cpp.cmake 2>/dev/null | head -n 1 | sed 's|.*/|  hclust 期望: |'
