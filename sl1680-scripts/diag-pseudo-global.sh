#!/bin/bash
echo "############ zlib do_package error signature ############"
CL=$(ls -t /home/astra/sdk/build-sl1680/tmp/work/cortexa73-poky-linux/zlib/1.3.1/temp/log.do_package.* 2>/dev/null | head -1)
tail -15 "$CL"

echo
echo "############ disk space ############"
df -h ~ /tmp /home/astra/sdk 2>/dev/null | sort -u

echo
echo "############ memory ############"
free -h

echo
echo "############ pseudo version + host kernel ############"
uname -r
ls -la /home/astra/sdk/build-sl1680/tmp/sysroots-components/x86_64/pseudo-native/usr/bin/pseudo 2>/dev/null
/home/astra/sdk/build-sl1680/tmp/sysroots-components/x86_64/pseudo-native/usr/bin/pseudo -h 2>&1 | head -3

echo
echo "############ is ABI/PSEUDO env set weird? check for known WSL pseudo issue ############"
grep -rE 'PSEUDO' /home/astra/sdk/build-sl1680/conf/local.conf 2>/dev/null || echo "(no PSEUDO in local.conf)"
