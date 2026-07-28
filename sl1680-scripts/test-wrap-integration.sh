#!/bin/bash
cd ~/sdk
export MACHINE=sl1680
export ACCEPT_SYNA_EULA=1
. meta-synaptics/setup/setup-environment >/dev/null 2>&1

# Prepend the openat2-neutralizing wrappers so bitbake's HOSTTOOLS resolves
# tar/cp/etc. to them.
export PATH="/home/astra/toolwrap:$PATH"

# Force bitbake to rebuild hosttools with our PATH: remove stale hosttools tar.
rm -f ~/sdk/build-sl1680/tmp/hosttools/tar ~/sdk/build-sl1680/tmp/hosttools/cp 2>/dev/null

echo "### which tar resolves to now ###"
which tar

echo "### force zlib do_package with wrappers active ###"
bitbake -f -c package zlib > /tmp/zlibwrap.log 2>&1
echo "exit=$?"
tail -8 /tmp/zlibwrap.log
echo "### hosttools/tar target ###"
ls -la ~/sdk/build-sl1680/tmp/hosttools/tar 2>/dev/null
