#!/bin/bash
# Diagnostic: source env + add layer, capture every step's exit status.
cd ~/sdk
export MACHINE=sl1680
export ACCEPT_SYNA_EULA=1

echo "### sourcing setup-environment ###"
. meta-synaptics/setup/setup-environment
echo "setup exit=$? ; PWD=$(pwd) ; BUILDDIR=$BUILDDIR"

echo "### bitbake-layers show-layers ###"
bitbake-layers show-layers 2>&1 | tail -20
echo "show-layers exit=$?"

echo "### try add-layer ###"
if bitbake-layers show-layers 2>/dev/null | grep -q 'meta-tcm2-touch'; then
    echo "already added"
else
    bitbake-layers add-layer "${TOPDIR}/../meta-tcm2-touch"
    echo "add-layer exit=$?"
fi

echo "### bblayers.conf tail ###"
tail -8 "${TOPDIR}/conf/bblayers.conf"

echo "### parse-check our recipe ###"
bitbake-layers show-recipes 'synaptics-tcm2' 2>&1 | tail -15
