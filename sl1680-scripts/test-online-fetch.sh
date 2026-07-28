#!/bin/bash
cd ~/sdk
export MACHINE=sl1680 ACCEPT_SYNA_EULA=1
pkill -9 -f 'bitbake-server' 2>/dev/null; pkill -9 -f 'bitbake/bin/bitbake' 2>/dev/null; sleep 2
. meta-synaptics/setup/setup-environment >/dev/null 2>&1
export PATH="/home/astra/toolwrap:$PATH"

echo "### online fetch (MTU 1280, shallow mirrors pre-placed) ###"
bitbake -c fetch optee-os synasdk-preboot 2>&1 | tail -14
echo "=== exit: ${PIPESTATUS[0]} ==="
