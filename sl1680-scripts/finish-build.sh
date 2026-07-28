#!/bin/bash
cd ~/sdk
export MACHINE=sl1680 ACCEPT_SYNA_EULA=1
pkill -9 -f 'bitbake-server' 2>/dev/null; pkill -9 -f 'bitbake/bin/bitbake' 2>/dev/null; sleep 2
. meta-synaptics/setup/setup-environment >/dev/null 2>&1
export PATH="/home/astra/toolwrap:$PATH"
for t in tar cp rsync install mv ln mkdir cpio bzip2 gzip; do rm -f "$BUILDDIR/tmp/hosttools/$t" 2>/dev/null; done

echo "### does the MAIN synaptics-tcm2 deb wrongly provide kernel-module-...? ###"
MAIN=$(find ~/sdk/build-sl1680/tmp/deploy/deb -name 'synaptics-tcm2_1.8.0*.deb' 2>/dev/null | head -1)
dpkg-deb -f "$MAIN" Package Provides 2>/dev/null

echo
echo "### clean-rebuild module deb (no stale provides) ###"
bitbake -c cleansstate synaptics-tcm2 >/dev/null 2>&1
bitbake synaptics-tcm2 2>&1 | tail -3

echo
echo "### now finish the image: do_rootfs + image (single pass) ###"
bitbake astra-media 2>&1 | tail -15
echo "=== exit: ${PIPESTATUS[0]} ==="

echo
echo "### SYNAIMG present? ###"
ls -1 ~/sdk/build-sl1680/tmp/deploy/images/sl1680/SYNAIMG/ 2>/dev/null | head -30
