#!/bin/bash
cd ~/sdk
export MACHINE=sl1680
export ACCEPT_SYNA_EULA=1
. meta-synaptics/setup/setup-environment >/dev/null 2>&1
pkill -f 'bitbake/bin/bitbake' 2>/dev/null; sleep 2

echo "### clean + rebuild synaptics-tcm2 (retry parse up to 3x for flaky net) ###"
bitbake -c cleansstate synaptics-tcm2 >/dev/null 2>&1
OK=0
for a in 1 2 3; do
  echo "--- attempt $a ---"
  OUT=$(bitbake synaptics-tcm2 2>&1)
  echo "$OUT" | tail -6
  if echo "$OUT" | grep -q 'all succeeded'; then OK=1; break; fi
  if echo "$OUT" | grep -qE 'do_compile.*Failed|error:'; then
     echo ">>> COMPILE ERROR — showing:"; echo "$OUT" | grep -iE 'error:|Failed' | head -15; break
  fi
  sleep 10
done
echo "OK=$OK"

echo "### .ko produced? ###"
find ~/sdk/build-sl1680/tmp/work/*/synaptics-tcm2 -name 'synaptics_tcm2.ko' 2>/dev/null | head
