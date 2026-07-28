#!/bin/bash
set -e
cd ~/sdk
export MACHINE=sl2619
export ACCEPT_SYNA_EULA=1
. meta-synaptics/setup/setup-environment

LOG=~/sdk/build-sl2619/build.log
{
  echo "=== bitbake astra-media start: $(date -Iseconds) ==="
  echo "BUILDDIR: $BUILDDIR"
  echo "PID: $$"
  bitbake astra-media 2>&1
  EXIT=$?
  echo "=== bitbake astra-media end: $(date -Iseconds) exit=$EXIT ==="
} >>"$LOG" 2>&1
