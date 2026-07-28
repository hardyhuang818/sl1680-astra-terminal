#!/bin/bash
CL=$(ls -t /home/astra/sdk/build-sl1680/tmp/work/sl1680-poky-linux/astra-media/1.0/temp/log.do_rootfs.* 2>/dev/null | head -1)
echo "log: $CL"
echo "--- apt/package error lines ---"
grep -nE 'E:|Unable|not install|held|Depends|but it is not|returned 100|Err:|W:|conflict|broken' "$CL" 2>/dev/null | head -40
echo
echo "--- tail 40 ---"
tail -40 "$CL"
