#!/bin/bash
P=/home/astra/sdk/poky/meta/classes-recipe/cmake.bbclass
echo "════ cmake.bbclass 里 cmake 调用的参数顺序 ════"
sed -n '165,205p' $P | sed 's/^/  /'
echo
echo "════ 实际 run.do_configure 里的完整命令行 ════"
W=/home/astra/sdk/build-sl1680/tmp/work/cortexa73-poky-linux/sherpa-onnx/1.13.4
R=$(ls -t $W/temp/run.do_configure.* 2>/dev/null | head -n 1)
grep -A30 "cmake \\\\" "$R" 2>/dev/null | grep -nE "FETCHCONTENT|EXTRA|SHERPA_ONNX_ENABLE_TTS|^\s*-D" | head -n 25 | sed 's/^/  /'
