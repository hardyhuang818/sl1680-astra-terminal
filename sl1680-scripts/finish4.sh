#!/bin/bash
# Set MTU 1280 (WSL resets it), then build astra-media with retries to ride out
# the flaky torq parse-time ls-remote. Explicit deb dependency already in the
# bbappend forces our kernel module into the rootfs feed.
sudo ip link set dev eth0 mtu 1280 2>/dev/null

cd ~/sdk
export MACHINE=sl1680 ACCEPT_SYNA_EULA=1
pkill -9 -f 'bitbake-server' 2>/dev/null; pkill -9 -f 'bitbake/bin/bitbake' 2>/dev/null; sleep 2
. meta-synaptics/setup/setup-environment >/dev/null 2>&1
export PATH="/home/astra/toolwrap:$PATH"
for t in tar cp rsync install mv ln mkdir cpio bzip2 gzip; do rm -f "$BUILDDIR/tmp/hosttools/$t" 2>/dev/null; done

bitbake -c cleansstate astra-media >/dev/null 2>&1

EXIT=1
for a in 1 2 3 4 5 6; do
  echo "=== attempt $a $(date +%T) ==="
  bitbake astra-media > /tmp/finish4.log 2>&1
  EXIT=$?
  tail -4 /tmp/finish4.log
  [ $EXIT -eq 0 ] && { echo ">>> BUILD OK"; break; }
  if grep -q 'Unable to locate package kernel-module-synaptics-tcm2' /tmp/finish4.log; then
     echo ">>> STILL feed issue — stopping retries"; break
  fi
  echo ">>> attempt $a failed (likely transient parse/net), retrying in 15s"
  sleep 15
done

echo
echo "### our deb staged into feed? ###"
ls ~/sdk/build-sl1680/tmp/work/sl1680-poky-linux/astra-media/1.0/oe-rootfs-repo/sl1680/kernel-module-synaptics-tcm2* 2>/dev/null && echo STAGED || echo "not staged"

echo
echo "### SYNAIMG present? ###"
ls -lh ~/sdk/build-sl1680/tmp/deploy/images/sl1680/SYNAIMG/ 2>/dev/null | head -30
