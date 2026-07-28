#!/bin/bash
set -e
SRC=~/sdk/build-sl1680/tmp/deploy/images/sl1680
DEST="/mnt/d/Claude code/Case44_RK3568/delivery_sl1680"
IMG="$DEST/SYNAIMG"          # = the "eMMCimg" folder the flashing tools expect
KMOD="$DEST/kernel-module"    # standalone .ko + .dtbo for manual testing
LAYER="$DEST/meta-tcm2-touch" # integration source

echo "### prepare dirs ###"
mkdir -p "$IMG" "$KMOD"

echo "### 1) SYNAIMG flashing images (2.4G) ###"
cp -f "$SRC/SYNAIMG/"* "$IMG/"
echo "  copied $(ls "$IMG" | wc -l) files"

echo "### 2) standalone .ko + .dtbo (manual insmod / dtoverlay) ###"
find ~/sdk/build-sl1680/tmp/work/sl1680-poky-linux/synaptics-tcm2 -name 'synaptics_tcm2.ko' -path '*packages-split/kernel-module-*' -exec cp -f {} "$KMOD/" \; 2>/dev/null
cp -f "$SRC/dolphin-tcm2-touch-overlay.dtbo" "$KMOD/" 2>/dev/null
cp -f "$SRC/dolphin-td7800-lvds-overlay.dtbo" "$KMOD/" 2>/dev/null
ls -1 "$KMOD/"

echo "### 3) meta-tcm2-touch layer source (recipe + overlays, without tarball) ###"
rm -rf "$LAYER"
mkdir -p "$LAYER"
cp -rf ~/sdk/meta-tcm2-touch/* "$LAYER/" 2>/dev/null
# drop the 2.2MB driver tarball copy inside the layer to keep it light
find "$LAYER" -name '*.tar.gz' -delete 2>/dev/null
echo "  layer files:"; find "$LAYER" -type f | sed "s|$LAYER/||"

echo
echo "### done. sizes: ###"
du -sh "$IMG" "$KMOD" "$LAYER" 2>/dev/null
echo "### emmc_image_list (flash order) ###"
cat "$IMG/emmc_image_list" 2>/dev/null
