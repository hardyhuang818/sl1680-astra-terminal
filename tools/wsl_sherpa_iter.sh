#!/bin/bash
# 单次调用内完成：同步 recipe -> 跑 configure -> 分析 -> 扫出所有嵌套依赖
cp "/mnt/d/Claude code/Case6_Astra/meta-dlsdk/recipes-ai/sherpa-onnx/sherpa-onnx_1.13.4.bb" \
   /home/astra/sdk/meta-dlsdk/recipes-ai/sherpa-onnx/sherpa-onnx_1.13.4.bb
cd /home/astra/sdk
set +e
source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1
W=/home/astra/sdk/build-sl1680/tmp/work/cortexa73-poky-linux/sherpa-onnx/1.13.4
OUT=/home/astra/sdk/_iter.txt

bitbake -c configure sherpa-onnx > $OUT 2>&1
RC=$?
L=$(grep "Logfile of failure stored in:" $OUT | tail -n 1 | sed 's/.*stored in: //')
[ -z "$L" ] && L=$(ls -t $W/temp/log.do_configure.[0-9]* 2>/dev/null | head -n 1)

if [ $RC -eq 0 ]; then echo "✅✅✅ do_configure 通过！"; else echo "❌ rc=$RC   日志: ${L##*/}"; fi

echo
echo "════ 命中本地包 ════"
grep "Found local downloaded" "$L" 2>/dev/null | sed 's|.*downloaded ||' | sed "s|$W/git/|  ✓ |" | sort -u

echo
echo "════ ⚠️ 仍在联网的 ════"
grep -E "^-- Downloading.*https://" "$L" 2>/dev/null | sed 's/^-- Downloading /  /' | sort -u
echo "  (以上为空 = 全本地)"

echo
echo "════ 失败点 ════"
grep -E "Could not resolve host|Build step for .* failed|which is not an existing directory" "$L" 2>/dev/null | sort -u | sed 's/^/  /'
grep -A3 "CMake Error" "$L" 2>/dev/null | head -n 12 | sed "s|$W|<W>|g" | sed 's/^/  /'

echo
echo "════ 已解出的子项目 ════"
ls $W/build/_deps 2>/dev/null | grep -- "-src$" | tr '\n' ' ' | sed 's/^/  /'; echo

echo
echo "════ ★ 全部嵌套依赖清单(一次性扫出，供批量补进 SRC_URI) ════"
find $W/build/_deps -maxdepth 3 -name "*.cmake" 2>/dev/null | while read f; do
  grep -q "possible_file_locations" "$f" || continue
  fn=$(grep -oE '\$\{CMAKE_SOURCE_DIR\}/[^ )]*' "$f" | head -n 1 | sed 's|.*/||')
  [ -z "$fn" ] && continue
  # 只列 ${S} 里还没有的
  [ -f "$W/git/$fn" ] && continue
  url=$(grep -oE 'https://[^"$) ]*\.(tar\.gz|zip)' "$f" | head -n 1)
  sha=$(grep -oE 'SHA256=[a-f0-9]{64}' "$f" | head -n 1 | cut -d= -f2)
  owner=$(echo "$f" | sed "s|$W/build/_deps/||; s|/cmake/.*||")
  printf "  [%s] %s\n    URL: %s\n    SHA: %s\n" "$owner" "$fn" "$url" "$sha"
done
