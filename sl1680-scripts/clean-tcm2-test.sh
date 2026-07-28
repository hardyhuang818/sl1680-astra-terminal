#!/bin/bash
# Kill ALL bitbake incl. the cooker daemon, then a fresh build of just the
# module with the wrapper PATH active — confirms the openat2 fix works end-to-end.
pkill -9 -f 'bitbake-server' 2>/dev/null
pkill -9 -f 'bitbake' 2>/dev/null
sleep 3
echo "remaining bitbake procs:"; pgrep -af bitbake | grep -v pgrep || echo "(none)"

cd ~/sdk
export MACHINE=sl1680 ACCEPT_SYNA_EULA=1
. meta-synaptics/setup/setup-environment >/dev/null 2>&1
export PATH="/home/astra/toolwrap:$PATH"
rm -f "$BUILDDIR"/tmp/hosttools/{tar,cp,rsync,install,mv,ln,mkdir,cpio} 2>/dev/null

echo "which tar: $(which tar)"
echo "### fresh bitbake synaptics-tcm2 (compile+install+package) ###"
bitbake -c cleansstate synaptics-tcm2 >/dev/null 2>&1
bitbake synaptics-tcm2 > /tmp/tcm2clean.log 2>&1
echo "exit=$?"
tail -8 /tmp/tcm2clean.log
echo "--- pseudo errors in this run? ---"
grep -cE 'unknown base path|Bad address' /tmp/tcm2clean.log
echo "--- packaged .ko? ---"
find ~/sdk/build-sl1680/tmp/work/*/synaptics-tcm2/*/packages-split -name 'synaptics_tcm2.ko' 2>/dev/null | head
