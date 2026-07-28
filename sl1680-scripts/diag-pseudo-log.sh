#!/bin/bash
Z=/home/astra/sdk/build-sl1680/tmp/work/cortexa73-poky-linux/zlib/1.3.1

echo "############ pseudo.log (root cause of fd tracking loss) ############"
find "$Z" -name 'pseudo.log' 2>/dev/null | while read f; do echo "== $f =="; tail -30 "$f"; done
# also the global pseudo log location
find /home/astra/sdk/build-sl1680/tmp -maxdepth 3 -name 'pseudo.log' 2>/dev/null | head -3

echo
echo "############ do_package run script — how is tar invoked / pseudo started ############"
RUN=$(ls -t "$Z"/temp/run.do_package.* 2>/dev/null | head -1)
echo "run: $RUN"
grep -nE 'pseudo|PSEUDO|fakeroot|perform_packagecopy' "$RUN" 2>/dev/null | head -10

echo
echo "############ do_package log — FIRST 25 lines of the actual error block ############"
CL=$(ls -t "$Z"/temp/log.do_package.* 2>/dev/null | head -1)
grep -n 'pseudo\|abort\|Bad address\|unknown base\|PSEUDO\|ERROR\|Exception\|tar:' "$CL" 2>/dev/null | head -25

echo
echo "############ which tar / tar version / is it host or sysroot ############"
which tar; tar --version | head -1
ls -la /home/astra/sdk/build-sl1680/tmp/sysroots-components/x86_64/*/usr/bin/tar 2>/dev/null | head

echo
echo "############ pseudo abort setting ############"
env | grep -i pseudo
