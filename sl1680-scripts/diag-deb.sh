#!/bin/bash
echo "### .deb files for our module in deploy ###"
find ~/sdk/build-sl1680/tmp/deploy/deb -iname '*synaptics-tcm2*' 2>/dev/null
find ~/sdk/build-sl1680/tmp/deploy/deb -iname '*kernel-module-synaptics*' 2>/dev/null

echo
echo "### what does the kernel-module deb Provide? ###"
DEB=$(find ~/sdk/build-sl1680/tmp/deploy/deb -iname 'kernel-module-synaptics-tcm2*.deb' 2>/dev/null | head -1)
echo "deb: $DEB"
if [ -n "$DEB" ]; then
    dpkg-deb -f "$DEB" Package Provides Depends 2>/dev/null
fi

echo
echo "### is it in the rootfs apt feed (oe-rootfs-repo)? ###"
find ~/sdk/build-sl1680/tmp/work/sl1680-poky-linux/astra-media/1.0/oe-rootfs-repo -iname '*synaptics-tcm2*' 2>/dev/null | head

echo
echo "### PACKAGES actually produced by the recipe ###"
ls ~/sdk/build-sl1680/tmp/work/sl1680-poky-linux/synaptics-tcm2/1.8.0/packages-split/ 2>/dev/null
