#!/bin/bash
cd ~/sdk
export MACHINE=sl1680
export ACCEPT_SYNA_EULA=1
. meta-synaptics/setup/setup-environment >/dev/null 2>&1
pkill -f 'bitbake/bin/bitbake' 2>/dev/null; sleep 2

echo "### rebuild pseudo-native ###"
bitbake -c cleansstate pseudo-native 2>&1 | tail -2
bitbake pseudo-native 2>&1 | tail -4

echo "### retry synaptics-tcm2 do_package (force) ###"
for a in 1 2 3; do
  OUT=$(bitbake synaptics-tcm2 2>&1)
  if echo "$OUT" | grep -q 'all succeeded'; then echo "attempt $a: ALL SUCCEEDED"; break; fi
  if echo "$OUT" | grep -q 'do_package'; then echo "attempt $a: do_package still failing"; echo "$OUT" | tail -4; else echo "$OUT" | tail -4; fi
  sleep 8
done

echo "### is the module packaged now? ###"
find ~/sdk/build-sl1680/tmp/work/*/synaptics-tcm2/*/packages-split -name 'synaptics_tcm2.ko' 2>/dev/null | head
ls ~/sdk/build-sl1680/tmp/deploy/*/*/kernel-module-synaptics-tcm2* 2>/dev/null | head
