#!/bin/bash
cd ~/sdk
export MACHINE=sl1680 ACCEPT_SYNA_EULA=1
pkill -9 -f 'bitbake-server' 2>/dev/null; pkill -9 -f 'bitbake/bin/bitbake' 2>/dev/null; sleep 2
. meta-synaptics/setup/setup-environment >/dev/null 2>&1
export PATH="/home/astra/toolwrap:$PATH"
for t in tar cp rsync install mv ln mkdir cpio bzip2 gzip; do rm -f "$BUILDDIR/tmp/hosttools/$t" 2>/dev/null; done

echo "### clean image + rebuild (explicit deb dependency now forces feed staging) ###"
bitbake -c cleansstate astra-media 2>&1 | tail -2
bitbake astra-media 2>&1 | tail -20
echo "=== exit: ${PIPESTATUS[0]} ==="

echo
echo "### is our deb now in the feed? ###"
ls ~/sdk/build-sl1680/tmp/work/sl1680-poky-linux/astra-media/1.0/oe-rootfs-repo/sl1680/kernel-module-synaptics-tcm2* 2>/dev/null && echo "  ^ STAGED" || echo "  not staged"

echo
echo "### SYNAIMG present? ###"
ls -lh ~/sdk/build-sl1680/tmp/deploy/images/sl1680/SYNAIMG/ 2>/dev/null | head -30
