#!/bin/bash
echo "### stop all bitbake + servers ###"
pkill -f 'bitbake' 2>/dev/null; sleep 3
pgrep -af 'bitbake' | grep -v pgrep | head || echo "(no bitbake procs)"

echo
echo "### current hosttools/tar target ###"
ls -la ~/sdk/build-sl1680/tmp/hosttools/tar 2>/dev/null

echo
echo "### does the failing tcm2 do_package log show our wrapper being used? ###"
CL=$(ls -t ~/sdk/build-sl1680/tmp/work/sl1680-poky-linux/synaptics-tcm2/1.8.0/temp/log.do_package.* 2>/dev/null | head -1)
echo "log: $CL"
grep -m1 -E 'unknown base path|Bad address' "$CL" 2>/dev/null && echo ">> pseudo STILL failing in this log"

echo
echo "### check: does the seccomp filter survive inside pseudo? (openat2 under pseudo+wrapper) ###"
PSEUDO=/home/astra/sdk/build-sl1680/tmp/sysroots-components/x86_64/pseudo-native/usr/bin/pseudo
rm -rf /tmp/pt2; mkdir -p /tmp/pt2/src/a/b /tmp/pt2/dst; echo x > /tmp/pt2/src/a/b/f
cd /tmp/pt2
echo "-- via hosttools/tar symlink under pseudo --"
"$PSEUDO" bash -c 'cd /tmp/pt2 && ~/sdk/build-sl1680/tmp/hosttools/tar -cf - -C src -p -S . | ~/sdk/build-sl1680/tmp/hosttools/tar -xf - -C dst' 2>&1 | grep -E 'Bad address|unknown base' | head -2 && echo ">> FAIL via hosttools" || echo ">> OK via hosttools (if no error lines above)"
find /tmp/pt2/dst
