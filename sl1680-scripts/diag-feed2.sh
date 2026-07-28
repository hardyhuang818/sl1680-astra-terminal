#!/bin/bash
R=~/sdk/build-sl1680/tmp/work/sl1680-poky-linux/astra-media/1.0/oe-rootfs-repo
D=~/sdk/build-sl1680/tmp/deploy/deb/sl1680

echo "### is our deb symlinked into the FRESH feed? ###"
ls -la "$R/sl1680/kernel-module-synaptics-tcm2"* 2>/dev/null || echo "NOT in feed dir"

echo
echo "### is it in the Packages index? ###"
grep -A6 '^Package: kernel-module-synaptics-tcm2' "$R/sl1680/Packages" 2>/dev/null || echo "NOT in Packages index"

echo
echo "### compare: a WORKING kernel module (isp) in the index ###"
grep -A6 '^Package: kernel-module-isp-6' "$R/sl1680/Packages" 2>/dev/null | head -8

echo
echo "### full metadata of our deb vs isp deb ###"
echo "-- OUR deb --"
dpkg-deb -f "$D/kernel-module-synaptics-tcm2-6.12.62_1.8.0-r0_arm64.deb" 2>/dev/null
echo "-- ISP deb (works) --"
dpkg-deb -f "$D/kernel-module-isp-6.12.62_6.12.62-r1_arm64.deb" 2>/dev/null

echo
echo "### does apt see the provide? query the feed dir directly ###"
grep -l 'kernel-module-synaptics-tcm2' "$R"/*/Packages 2>/dev/null || echo "provide/name NOT in any Packages index"
