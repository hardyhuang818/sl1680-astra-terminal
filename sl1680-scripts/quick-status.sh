#!/bin/bash
LOG=~/sdk/build-sl1680/build.log
pgrep -af 'bitbake/bin/bitbake' | grep -v pgrep | head -1 && echo ALIVE || echo GONE
echo "--- progress ---"
tail -3 "$LOG" 2>/dev/null | grep -oE 'Running task [0-9]+ of [0-9]+' | tail -1
echo "--- attempts / end ---"
grep -E 'bitbake attempt|attempt [0-9] failed|sl1680\) end' "$LOG" 2>/dev/null | tail -4
echo "--- any pseudo/package errors still? ---"
grep -cE 'unknown base path|Bad address' "$LOG" 2>/dev/null
echo "--- do_package/do_rootfs failures? ---"
grep -E 'ERROR: Task.*(do_package|do_rootfs)' "$LOG" 2>/dev/null | tail -5
echo "--- tcm2 result ---"
grep -E 'synaptics-tcm2.*(do_package|do_compile).*(Succeeded|Failed)' "$LOG" 2>/dev/null | tail -3
