#!/bin/bash
D=/home/astra/sdk/build-sl1680/tmp/work/cortexa73-poky-linux/sherpa-onnx/1.13.4/build/_deps
echo "════ 顶层 8 个包解出来了吗 ════"
ls $D 2>/dev/null | grep -- "-src$" | sed 's/^/  /'

echo
echo "════ 嵌套依赖：各子项目自己还要下什么 ════"
for d in $D/*-src; do
  n=$(basename "$d")
  ls $d/cmake/*.cmake >/dev/null 2>&1 || continue
  found=""
  for f in $d/cmake/*.cmake; do
    grep -q "FetchContent_Declare\|possible_file_locations" "$f" 2>/dev/null && found="$found $(basename $f .cmake)"
  done
  [ -n "$found" ] && echo "  $n ->$found"
done

echo
echo "════ 每个嵌套依赖的 期望文件名 / URL / HASH ════"
for d in $D/*-src; do
  for f in $d/cmake/*.cmake; do
    [ -f "$f" ] || continue
    grep -q "possible_file_locations" "$f" || continue
    name=$(basename "$f" .cmake)
    fn=$(grep -oE '\$\{CMAKE_SOURCE_DIR\}/[^ ]*' "$f" | head -n 1 | sed 's|.*/||')
    url=$(grep -oE 'https://[^"$)]*\.(tar\.gz|zip)' "$f" | head -n 1)
    sha=$(grep -oE 'SHA256=[a-f0-9]{64}' "$f" | head -n 1 | cut -d= -f2)
    [ -n "$fn" ] && printf "  %-22s %s\n    URL: %s\n    SHA: %s\n" "$name" "$fn" "$url" "$sha"
  done
done

echo
echo "════ 它找本地文件的路径列表(确认含 CMAKE_SOURCE_DIR) ════"
sed -n '/possible_file_locations/,/)/p' $D/kaldi_native_fbank-src/cmake/kissfft.cmake 2>/dev/null | sed 's/^/  /'
