#!/bin/bash
cd ~/sdk
export MACHINE=sl1680 ACCEPT_SYNA_EULA=1
. meta-synaptics/setup/setup-environment >/dev/null 2>&1

echo "### ta_enc SRCREV wanted by optee-os ###"
bitbake -e optee-os 2>/dev/null | grep -iE 'SRCREV_taenc|SRCREV.*taenc|ta_enc' | head -8
echo "branch tip we shallow-cloned: 83ad0847bbdc21be6df65ec4fb6d4b0cd6de9b61"

echo
echo "### preboot SRCREV wanted by synasdk-preboot ###"
bitbake -e synasdk-preboot 2>/dev/null | grep -iE 'SRCREV_preboot|SRCREV.*preboot' | head -8

echo
echo "### remote tip of each branch (ls-remote, small transfer) ###"
git ls-remote https://github.com/synaptics-astra/ta_enc scarthgap_6.12_v2.3.0 2>/dev/null
git ls-remote https://github.com/synaptics-astra/boot-preboot-prebuilts scarthgap_6.12_v2.3.0 2>/dev/null
