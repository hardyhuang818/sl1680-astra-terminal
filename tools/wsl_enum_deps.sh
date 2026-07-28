#!/bin/bash
S=/home/astra/sdk/build-sl1680/tmp/work/cortexa73-poky-linux/sherpa-onnx/1.13.4/git

echo "════ CMakeLists.txt 里 include 了哪些 cmake 模块(带条件) ════"
grep -nE "include\(cmake/|if\(SHERPA_ONNX_ENABLE|endif" $S/CMakeLists.txt | sed -n '/include(cmake/,$p' | grep -nE "include\(cmake/" | head -n 30 | sed 's/^/  /'
echo
echo "  完整上下文(500-580 行):"
sed -n '520,580p' $S/CMakeLists.txt | grep -nE "include\(cmake|if\(|endif|else" | sed 's/^/    /'

echo
echo "════ 每个模块期望的本地文件名 + URL + HASH ════"
for m in kaldi-native-fbank kaldi-decoder openfst simple-sentencepiece json espeak-ng-for-piper piper-phonemize cargs onnxruntime-linux-aarch64 hclust-cpp eigen; do
  f=$S/cmake/$m.cmake
  [ -f "$f" ] || continue
  echo "── $m.cmake"
  # CMAKE_SOURCE_DIR 那一行给出期望文件名
  grep -oE '\$\{CMAKE_SOURCE_DIR\}/[^ ]*' "$f" | head -n 1 | sed 's|.*/|     期望文件名: |'
  grep -oE 'https://github\.com[^"$)]*' "$f" | head -n 1 | sed 's/^/     URL: /'
  grep -oE 'SHA256=[a-f0-9]{64}' "$f" | head -n 1 | sed 's/^/     /'
done
