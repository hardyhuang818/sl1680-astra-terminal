#!/bin/bash
cd /home/astra/sdk
source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1
echo "════ 这组标志从哪来 ════"
grep -rn "SECURITY_STRINGFORMAT" poky/meta/conf/distro/include/*.inc 2>/dev/null | head -n 4 | sed 's/^/  /'
echo
echo "════ sherpa-onnx 当前的取值 ════"
bitbake -e sherpa-onnx 2>/dev/null > /tmp/se.txt
grep -E '^(SECURITY_STRINGFORMAT|SECURITY_CFLAGS|SECURITY_NO_PIE_CFLAGS)=' /tmp/se.txt | sed 's/^/  /'
echo "  CFLAGS 里的相关项:"
grep -m1 '^CFLAGS=' /tmp/se.txt | tr ' ' '\n' | grep -E "format|fortify|stack-protector" | sed 's/^/    /'
echo
echo "════ espeak-ng 自己怎么设 C 标志的 ════"
E=/home/astra/sdk/build-sl1680/tmp/work/cortexa73-poky-linux/sherpa-onnx/1.13.4/build/_deps/espeak_ng-src
grep -rn "CMAKE_C_FLAGS\|add_compile_options\|Wall" $E/CMakeLists.txt 2>/dev/null | head -n 8 | sed 's/^/  /'
