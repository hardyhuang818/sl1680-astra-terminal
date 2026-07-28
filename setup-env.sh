#!/bin/bash
set -e
cd ~/sdk
export MACHINE=sl2619
export ACCEPT_SYNA_EULA=1
# Sourcing here, then printing conf so we can verify
. meta-synaptics/setup/setup-environment
echo "=========================="
echo "PWD after setup: $(pwd)"
echo "BUILDDIR: $BUILDDIR"
echo "=========================="
ls -la conf/ 2>/dev/null || echo "no conf dir"
echo "--- local.conf MACHINE line(s) ---"
grep -E '^MACHINE' conf/local.conf || true
echo "--- bblayers.conf ---"
cat conf/bblayers.conf
