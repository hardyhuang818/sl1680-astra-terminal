#!/bin/bash
CL=$(ls -t /home/astra/sdk/build-sl1680/tmp/work/sl1680-poky-linux/astra-media/1.0/temp/log.do_rootfs.* 2>/dev/null | head -1)
echo "latest do_rootfs log: $CL"
echo "--- key errors ---"
grep -iE 'Unable to locate|Unable to install|E: |returned 100|inode mismatch|Fatal QA|Aborted' "$CL" 2>/dev/null | tail -10
echo "--- tail 15 ---"
tail -15 "$CL"
