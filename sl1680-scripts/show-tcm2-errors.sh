#!/bin/bash
W=~/sdk/build-sl1680/tmp/work/cortexa73-poky-linux/synaptics-tcm2
# find whichever arch subdir (cortexa73 poky linux) actually holds it
D=$(ls -d ~/sdk/build-sl1680/tmp/work/*/synaptics-tcm2/*/temp 2>/dev/null | head -1)
echo "temp dir: $D"

echo "############ do_populate_lic (md5) — correct checksum ############"
CL=$(ls -t "$D"/log.do_populate_lic.* 2>/dev/null | head -1)
[ -n "$CL" ] && grep -iE 'md5|checksum|LIC_FILES' "$CL" | head -10

echo
echo "############ do_compile error ############"
CO=$(ls -t "$D"/log.do_compile.* 2>/dev/null | head -1)
echo "compile log: $CO"
[ -n "$CO" ] && tail -50 "$CO"
