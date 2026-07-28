#!/bin/bash
cd ~/sdk
export MACHINE=sl1680 ACCEPT_SYNA_EULA=1
. meta-synaptics/setup/setup-environment >/dev/null 2>&1

echo "### can bitbake resolve the provide kernel-module-synaptics-tcm2 ? ###"
oe-pkgdata-util lookup-recipe kernel-module-synaptics-tcm2 2>&1 | head
echo "--- lookup-pkg (rprovides) ---"
oe-pkgdata-util lookup-pkg kernel-module-synaptics-tcm2 2>&1 | head

echo
echo "### runtime provides recorded for our recipe ###"
oe-pkgdata-util list-pkg-files -p synaptics-tcm2 2>&1 | head
echo "--- versioned pkg ---"
oe-pkgdata-util lookup-recipe kernel-module-synaptics-tcm2-6.12.62 2>&1 | head

echo
echo "### is PACKAGES_DYNAMIC set for our recipe? ###"
bitbake -e synaptics-tcm2 2>/dev/null | grep -E '^PACKAGES_DYNAMIC=|^RPROVIDES' | head

echo
echo "### pkgdata runtime-rprovides file for the versioned pkg ###"
find ~/sdk/build-sl1680/tmp/pkgdata -name 'kernel-module-synaptics-tcm2*' 2>/dev/null
RUNPKG=~/sdk/build-sl1680/tmp/pkgdata/sl1680/runtime/kernel-module-synaptics-tcm2-6.12.62
[ -f "$RUNPKG" ] && grep -iE 'RPROVIDES|PKG' "$RUNPKG" | head
