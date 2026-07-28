#!/bin/bash
# 交叉编译 dl_dptest (DP AUX 检测诊断工具) —— 与 build-dlface-wsl.sh 同一套工具链
set -e

W=/home/astra/sdk/build-sl1680/tmp/work
CC=$W/sl1680-poky-linux/optee-os/4.5.0/recipe-sysroot-native/usr/bin/aarch64-poky-linux/aarch64-poky-linux-gcc
SYSROOT=$W/cortexa73-poky-linux/gstreamer1.0-plugins-base/1.22.12/recipe-sysroot

BASE="/mnt/d/Claude code/Case6_Astra"
SRC="$BASE/meta-dlsdk/recipes-graphics/dl-face/files/dl_dptest.c"
DLSDK_DIR="$BASE/meta-dlsdk/recipes-graphics/dlsdk/files"
OUT="$BASE/astra-xiaozhi/dl_dptest"

INC=/tmp/dlface-inc
mkdir -p $INC/dlsdk
cp "$DLSDK_DIR/dlsdk.h" $INC/dlsdk/

SCOMP=/home/astra/sdk/build-sl1680/tmp/sysroots-components/cortexa73
UDEV_DIR=$(dirname "$(ls $SCOMP/*/usr/lib/libudev.so.1 2>/dev/null | head -1)")

$CC --sysroot=$SYSROOT -O2 -Wall -o "$OUT" "$SRC" \
  -I$INC \
  -L"$DLSDK_DIR" -L$SCOMP/libusb1/usr/lib -L"$UDEV_DIR" \
  -Wl,--allow-shlib-undefined \
  -ldlsdk -lusb-1.0
file "$OUT" 2>/dev/null || true
echo "OK -> $OUT"
