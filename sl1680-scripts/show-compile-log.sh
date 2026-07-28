#!/bin/bash
D=~/sdk/build-sl1680/tmp/work/sl1680-poky-linux/synaptics-tcm2/1.8.0/temp

echo "############ do_populate_lic (why still failing?) ############"
LL=$(ls -t "$D"/log.do_populate_lic.* 2>/dev/null | head -1)
[ -n "$LL" ] && grep -iE 'md5|checksum|LIC_FILES|QA Issue|new md5' "$LL" | head -8

echo
echo "############ do_compile — real compiler error (last 60 lines) ############"
CL=$(ls -t "$D"/log.do_compile.* 2>/dev/null | head -1)
echo "log: $CL"
echo "--- grep errors ---"
grep -nE 'error:|Error |No such file|undefined|implicit declaration|make.*Error|\.c:[0-9]+' "$CL" 2>/dev/null | head -30
echo "--- tail ---"
tail -40 "$CL"
