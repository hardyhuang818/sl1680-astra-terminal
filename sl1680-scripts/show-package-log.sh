#!/bin/bash
D=/home/astra/sdk/build-sl1680/tmp/work/sl1680-poky-linux/synaptics-tcm2/1.8.0/temp
CL=$(ls -t "$D"/log.do_package.* 2>/dev/null | head -1)
echo "log: $CL"
echo "--- errors / QA ---"
grep -iE 'error|QA |not shipped|installed-vs-shipped|strip|fatal|Exception|Traceback' "$CL" 2>/dev/null | head -30
echo "--- tail 30 ---"
tail -30 "$CL"
