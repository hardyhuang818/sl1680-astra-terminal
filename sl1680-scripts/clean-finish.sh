#!/bin/bash
cd ~/sdk
export MACHINE=sl1680 ACCEPT_SYNA_EULA=1
pkill -9 -f 'bitbake-server' 2>/dev/null; pkill -9 -f 'bitbake/bin/bitbake' 2>/dev/null; sleep 2
. meta-synaptics/setup/setup-environment >/dev/null 2>&1
export PATH="/home/astra/toolwrap:$PATH"
for t in tar cp rsync install mv ln mkdir cpio bzip2 gzip; do rm -f "$BUILDDIR/tmp/hosttools/$t" 2>/dev/null; done

echo "### cleansstate the image only (proper pseudo-db cleanup; deps untouched) ###"
bitbake -c cleansstate astra-media 2>&1 | tail -3

echo
echo "### build astra-media (fresh do_rootfs + feed + image) ###"
bitbake astra-media 2>&1 | tail -20
echo "=== exit: ${PIPESTATUS[0]} ==="

echo
echo "### SYNAIMG present? ###"
ls -lh ~/sdk/build-sl1680/tmp/deploy/images/sl1680/SYNAIMG/ 2>/dev/null | head -30
