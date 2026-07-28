#!/bin/bash
R=~/sdk/build-sl1680/tmp/work/sl1680-poky-linux/astra-media/1.0/oe-rootfs-repo
D=~/sdk/build-sl1680/tmp/deploy/deb

echo "### total debs in deploy/deb/sl1680 vs symlinks in feed/sl1680 ###"
echo "deploy sl1680: $(ls "$D/sl1680"/*.deb 2>/dev/null | wc -l)"
echo "feed sl1680:   $(ls "$R/sl1680"/*.deb 2>/dev/null | wc -l)"

echo
echo "### is OUR deb in deploy but not feed? ###"
ls "$D/sl1680"/kernel-module-synaptics-tcm2*.deb 2>/dev/null && echo "  ^ in deploy"
ls "$R/sl1680"/kernel-module-synaptics-tcm2*.deb 2>/dev/null && echo "  ^ in feed" || echo "  NOT in feed"

echo
echo "### how are feed entries created — symlink or copy? sample ###"
ls -la "$R/sl1680"/kernel-module-isp*.deb 2>/dev/null | head -1

echo
echo "### MANUAL TEST: symlink our deb into feed, re-index, see if apt finds it ###"
ln -sf "$D/sl1680/kernel-module-synaptics-tcm2-6.12.62_1.8.0-r0_arm64.deb" "$R/sl1680/" 2>/dev/null
cd "$R/sl1680"
PATH="/home/astra/toolwrap:$PATH"
NATIVE=~/sdk/build-sl1680/tmp/work/sl1680-poky-linux/astra-media/1.0/recipe-sysroot-native/usr/bin
"$NATIVE/apt-ftparchive" packages . > Packages 2>/dev/null
grep -c '^Package: kernel-module-synaptics-tcm2' Packages && echo "  ^ NOW indexed after manual symlink+reindex" || echo "  still not indexed"
grep -A2 '^Package: kernel-module-synaptics-tcm2-6' Packages | head
