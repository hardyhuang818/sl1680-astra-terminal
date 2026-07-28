#!/bin/bash
# 交叉编译 astra_xiaozhi (在 WSL Ubuntu-22.04 里跑)
# 工具链: Yocto gcc-cross-aarch64 13.3.0
# sysroot: gst-plugins-base 的 recipe-sysroot —— alsa+opus+libc 一站齐活
set -e

W=/home/astra/sdk/build-sl1680/tmp/work
CC=$W/sl1680-poky-linux/optee-os/4.5.0/recipe-sysroot-native/usr/bin/aarch64-poky-linux/aarch64-poky-linux-gcc
SYSROOT=$W/cortexa73-poky-linux/gstreamer1.0-plugins-base/1.22.12/recipe-sysroot

SRC="$(dirname "$0")/astra_xiaozhi.c"
OUT="$(dirname "$0")/astra_xiaozhi"

$CC --sysroot=$SYSROOT -O2 -Wall -o "$OUT" "$SRC" -lopus -lasound -lpthread -lm
file "$OUT" 2>/dev/null || true
echo "OK -> $OUT"
