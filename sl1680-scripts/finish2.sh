#!/bin/bash
cd ~/sdk
export MACHINE=sl1680 ACCEPT_SYNA_EULA=1
pkill -9 -f 'bitbake-server' 2>/dev/null; pkill -9 -f 'bitbake/bin/bitbake' 2>/dev/null; sleep 2
. meta-synaptics/setup/setup-environment >/dev/null 2>&1
export PATH="/home/astra/toolwrap:$PATH"
for t in tar cp rsync install mv ln mkdir cpio bzip2 gzip; do rm -f "$BUILDDIR/tmp/hosttools/$t" 2>/dev/null; done

echo "### verify PACKAGES_DYNAMIC now includes kernel-module ###"
bitbake -e synaptics-tcm2 2>/dev/null | grep -E '^PACKAGES_DYNAMIC='

echo
echo "### can bitbake now resolve the provide to a recipe (dep-time)? ###"
oe-pkgdata-util lookup-recipe kernel-module-synaptics-tcm2 2>&1 | head -3

echo
echo "### rebuild module deb (new PACKAGES_DYNAMIC) ###"
bitbake -c cleansstate synaptics-tcm2 >/dev/null 2>&1
bitbake synaptics-tcm2 2>&1 | tail -2

echo
echo "### clean image + rebuild rootfs + image ###"
bitbake -c cleansstate astra-media 2>&1 | tail -2
bitbake astra-media 2>&1 | tail -16
echo "=== exit: ${PIPESTATUS[0]} ==="

echo
echo "### SYNAIMG present? ###"
ls -lh ~/sdk/build-sl1680/tmp/deploy/images/sl1680/SYNAIMG/ 2>/dev/null | head -30
