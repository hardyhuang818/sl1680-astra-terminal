#!/bin/bash
R=~/sdk/build-sl1680/tmp/work/sl1680-poky-linux/astra-media/1.0
echo "### oe-rootfs-repo arch dirs ###"
ls -la "$R/oe-rootfs-repo/" 2>/dev/null

echo
echo "### is our deb symlinked into any feed arch dir? ###"
find "$R/oe-rootfs-repo/" -iname '*synaptics-tcm2*' 2>/dev/null
find "$R/oe-rootfs-repo/" -iname '*kernel-module*' 2>/dev/null | head

echo
echo "### which arch dirs exist + do they have our module in Packages index? ###"
for d in "$R"/oe-rootfs-repo/*/; do
  [ -f "$d/Packages" ] || continue
  echo "-- $d --"
  grep -c '^Package:' "$d/Packages" 2>/dev/null
  grep -i 'synaptics-tcm2' "$d/Packages" 2>/dev/null | head
done

echo
echo "### apt sources.list the rootfs uses ###"
find "$R" -name 'sources.list*' 2>/dev/null | head
cat "$R"/apt/etc/apt/sources.list* 2>/dev/null 2>&1 | head -20
find "$R" -path '*apt*sources.list*' -exec cat {} \; 2>/dev/null | head -20

echo
echo "### deploy deb dir for sl1680 arch — our module present? ###"
ls ~/sdk/build-sl1680/tmp/deploy/deb/sl1680/ 2>/dev/null | grep -i 'synaptics-tcm2\|kernel-module'
