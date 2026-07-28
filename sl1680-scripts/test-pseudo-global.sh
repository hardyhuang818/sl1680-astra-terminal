#!/bin/bash
cd ~/sdk
export MACHINE=sl1680
export ACCEPT_SYNA_EULA=1
. meta-synaptics/setup/setup-environment >/dev/null 2>&1
pkill -f 'bitbake/bin/bitbake' 2>/dev/null; sleep 2

echo "### force do_package on a known-good simple recipe (zlib) ###"
OUT=$(bitbake -f -c package zlib 2>&1)
echo "$OUT" | tail -6
if echo "$OUT" | grep -qE 'Bad address|unknown base path|do_package.*fail'; then
   echo ">>> PSEUDO GLOBALLY BROKEN (zlib do_package also fails)"
elif echo "$OUT" | grep -q 'all succeeded\|Tasks Summary'; then
   echo ">>> zlib do_package OK — issue is SPECIFIC to synaptics-tcm2"
fi

echo
echo "### also try force do_package on another kernel module if present (isp) ###"
OUT2=$(bitbake -f -c package synasdk-drivers-isp 2>&1)
echo "$OUT2" | tail -5
if echo "$OUT2" | grep -qE 'Bad address|unknown base path'; then
   echo ">>> isp (kernel module) do_package ALSO fails -> kernel-module packaging broken"
elif echo "$OUT2" | grep -qE 'all succeeded|Tasks Summary'; then
   echo ">>> isp kernel-module do_package OK -> synaptics-tcm2 recipe is the difference"
fi
