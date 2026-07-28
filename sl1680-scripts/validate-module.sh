#!/bin/bash
# Isolated validation of the synaptics-tcm2 module compile (fast iteration).
cd ~/sdk
export MACHINE=sl1680
export ACCEPT_SYNA_EULA=1
. meta-synaptics/setup/setup-environment >/dev/null 2>&1

# make sure no stale bitbake holds the lock
pkill -f 'bitbake/bin/bitbake' 2>/dev/null
sleep 2

echo "### force-rebuild synaptics-tcm2 (clean + compile + install) ###"
bitbake -c cleansstate synaptics-tcm2 2>&1 | tail -3
bitbake synaptics-tcm2 2>&1 | tail -25
echo "### RESULT: exit above; check for do_compile/do_install success ###"

echo "### was the .ko produced/packaged? ###"
find ~/sdk/build-sl1680/tmp/work/*/synaptics-tcm2 -name 'synaptics_tcm2.ko' 2>/dev/null | head
