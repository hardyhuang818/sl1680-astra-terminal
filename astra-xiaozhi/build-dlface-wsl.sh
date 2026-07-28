#!/bin/bash
# 交叉编译 dl_face (WSL Ubuntu-22.04)
# sysroot 用 gst-plugins-base 的 recipe-sysroot(gstreamer/glib 头和库都在)
# libdlsdk.so 和 dlsdk.h 来自仓库 meta-dlsdk/recipes-graphics/dlsdk/files/
set -e

W=/home/astra/sdk/build-sl1680/tmp/work
CC=$W/sl1680-poky-linux/optee-os/4.5.0/recipe-sysroot-native/usr/bin/aarch64-poky-linux/aarch64-poky-linux-gcc
SYSROOT=$W/cortexa73-poky-linux/gstreamer1.0-plugins-base/1.22.12/recipe-sysroot

BASE="/mnt/d/Claude code/Case6_Astra"
SRC="$BASE/meta-dlsdk/recipes-graphics/dl-face/files/dl_face.c"
DLSDK_DIR="$BASE/meta-dlsdk/recipes-graphics/dlsdk/files"
OUT="$BASE/astra-xiaozhi/dl_face"

# dlsdk.h 要能以 dlsdk/dlsdk.h 形式 include
INC=/tmp/dlface-inc
mkdir -p $INC/dlsdk
cp "$DLSDK_DIR/dlsdk.h" $INC/dlsdk/

# gstappsink.h/libgstapp 在 gst-plugins-base 自己的 image/ 输出里(不在其依赖 sysroot)
GSTIMG=$W/cortexa73-poky-linux/gstreamer1.0-plugins-base/1.22.12/image

SCOMP=/home/astra/sdk/build-sl1680/tmp/sysroots-components/cortexa73
UDEV_DIR=$(dirname "$(ls $SCOMP/*/usr/lib/libudev.so.1 2>/dev/null | head -1)")

$CC --sysroot=$SYSROOT -O2 -Wall -o "$OUT" "$SRC" \
  -I$INC \
  -I$GSTIMG/usr/include/gstreamer-1.0 \
  -I$SYSROOT/usr/include/gstreamer-1.0 \
  -I$SYSROOT/usr/include/glib-2.0 \
  -I$SYSROOT/usr/lib/glib-2.0/include \
  -L"$DLSDK_DIR" -L$GSTIMG/usr/lib \
  -L$SCOMP/libusb1/usr/lib -L"$UDEV_DIR" \
  -Wl,--allow-shlib-undefined \
  -ldlsdk -lusb-1.0 \
  -lgstreamer-1.0 -lgstapp-1.0 -lgobject-2.0 -lglib-2.0 -lm
file "$OUT" 2>/dev/null || true
echo "OK -> $OUT"
