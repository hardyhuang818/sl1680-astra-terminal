#!/bin/bash
cd ~/sdk
export MACHINE=sl1680 ACCEPT_SYNA_EULA=1
pkill -9 -f 'bitbake-server' 2>/dev/null; pkill -9 -f 'bitbake/bin/bitbake' 2>/dev/null; sleep 2
. meta-synaptics/setup/setup-environment >/dev/null 2>&1
export PATH="/home/astra/toolwrap:$PATH"
for t in tar cp rsync install mv ln mkdir cpio bzip2 gzip; do rm -f "$BUILDDIR/tmp/hosttools/$t" 2>/dev/null; done

R=~/sdk/build-sl1680/tmp/work/sl1680-poky-linux/astra-media/1.0
echo "### wipe stale rootfs feed + work so it rebuilds from current deploy/deb ###"
rm -rf "$R/oe-rootfs-repo" "$R/rootfs" 2>/dev/null

echo "### confirm our deb is in deploy/deb/sl1680 ###"
ls ~/sdk/build-sl1680/tmp/deploy/deb/sl1680/kernel-module-synaptics-tcm2* 2>/dev/null

echo "### force do_rootfs (-C invalidates rootfs and re-runs it + do_image) ###"
bitbake -C rootfs astra-media 2>&1 | tail -18
echo "=== exit: ${PIPESTATUS[0]} ==="

echo
echo "### SYNAIMG present? ###"
ls -lh ~/sdk/build-sl1680/tmp/deploy/images/sl1680/SYNAIMG/ 2>/dev/null | head -30
