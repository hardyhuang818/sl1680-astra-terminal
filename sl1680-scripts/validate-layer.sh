#!/bin/bash
cd ~/sdk
export MACHINE=sl1680
export ACCEPT_SYNA_EULA=1
. meta-synaptics/setup/setup-environment >/dev/null 2>&1

echo "### add layer (abs path) ###"
if bitbake-layers show-layers 2>/dev/null | grep -q 'meta-tcm2-touch'; then
    echo "already added"
else
    bitbake-layers add-layer /home/astra/sdk/meta-tcm2-touch && echo "add-layer OK"
fi

echo "### our recipe visible? ###"
bitbake-layers show-recipes synaptics-tcm2 2>&1 | grep -A3 synaptics-tcm2

echo "### parse whole tree (catches recipe/bbappend syntax errors) ###"
bitbake -p 2>&1 | tail -8

echo "### confirm module + overlays wired into image/kernel ###"
bitbake -e astra-media 2>/dev/null | grep -E '^IMAGE_INSTALL=' | tr ' ' '\n' | grep -i tcm || echo "(tcm not in IMAGE_INSTALL — check)"
