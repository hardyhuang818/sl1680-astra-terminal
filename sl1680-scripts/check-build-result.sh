#!/bin/bash
LOG=~/sdk/build-sl1680/build.log
echo "############ attempt markers + end ############"
grep -E 'bitbake attempt|attempt [0-9] failed|sl1680\) end' "$LOG" 2>/dev/null

echo
echo "############ Tasks Summary / all succeeded ############"
grep -E 'Tasks Summary|all succeeded' "$LOG" 2>/dev/null | tail -3

echo
echo "############ ERRORs (unique) ############"
grep -E '^ERROR:' "$LOG" 2>/dev/null | sed -E 's/[0-9]{5,}//g' | sort -u | head -20

echo
echo "############ synaptics-tcm2 result ############"
grep -iE 'synaptics-tcm2.*(Succeeded|Failed|do_compile|do_install)' "$LOG" 2>/dev/null | tail -8

echo
echo "############ artifacts present? ############"
IMG=~/sdk/build-sl1680/tmp/deploy/images/sl1680
echo "-- SYNAIMG --"; ls -1 "$IMG/SYNAIMG/" 2>/dev/null | head -20
echo "-- .ko in build --"; find ~/sdk/build-sl1680/tmp/work/*/synaptics-tcm2 -name 'synaptics_tcm2.ko' 2>/dev/null | head
echo "-- our dtbos --"; ls -1 "$IMG/"*.dtbo 2>/dev/null | grep -iE 'tcm2|td7800|dolphin-td7800|dolphin-tcm2' ; find ~/sdk/build-sl1680/tmp -name 'dolphin-td7800-lvds-overlay.dtbo' -o -name 'dolphin-tcm2-touch-overlay.dtbo' 2>/dev/null | head
