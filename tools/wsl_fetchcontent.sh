#!/bin/bash
P=/home/astra/sdk/poky
W=/home/astra/sdk/build-sl1680/tmp/work/cortexa73-poky-linux/sherpa-onnx/1.13.4
L=$(ls -t $W/temp/log.do_configure.* 2>/dev/null | head -n 1)

echo "════ 假设：Yocto 的 cmake.bbclass 关掉了 FetchContent 联网 ════"
grep -rn "FETCHCONTENT" $P/meta/classes-recipe/cmake.bbclass $P/meta/classes*/cmake.bbclass 2>/dev/null | sed 's/^/  /'
echo "  (若有 FETCHCONTENT_FULLY_DISCONNECTED=ON，假设成立)"

echo
echo "════ 实际传给 cmake 的命令行里有没有它 ════"
grep -o "FETCHCONTENT[A-Z_]*=[A-Za-z0-9]*" "$L" 2>/dev/null | sort -u | sed 's/^/  /'
echo "  configure 命令行:"
grep -m1 "cmake " "$L" 2>/dev/null | tr ' ' '\n' | grep -E "^-D" | head -n 20 | sed 's/^/    /'

echo
echo "════ 反证：日志里有没有真正的下载失败信息 ════"
grep -iE "curl|download failed|Timeout|Connection|Could not resolve|HTTP" "$L" 2>/dev/null | head -n 8 | sed 's/^/  /'
echo "  (空 = 根本没尝试连网，符合被 DISCONNECTED 掐掉的特征)"

echo
echo "════ cmake 模块找本地文件的路径列表 ════"
sed -n '/possible_file_locations/,/endforeach/p' $W/git/cmake/kaldi-native-fbank.cmake 2>/dev/null | sed 's/^/  /'
