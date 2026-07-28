#!/bin/bash
CL=$(ls -t /home/astra/sdk/build-sl1680/tmp/work/sl1680-poky-linux/synaptics-tcm2/1.8.0/temp/log.do_package.* 2>/dev/null | head -1)
echo "log: $CL"
echo "--- error lines ---"
grep -nE 'ERROR|Error|Exception|QA|not shipped|installed-vs|Traceback|FileNotFound|KeyError|split' "$CL" 2>/dev/null | head -25
echo "--- tail 30 ---"
tail -30 "$CL"
