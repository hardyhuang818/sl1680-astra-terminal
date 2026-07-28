#!/bin/bash
D=/home/astra/sdk/build-sl1680/tmp/work/sl1680-poky-linux/synaptics-tcm2/1.8.0
CL=$(ls -t "$D"/temp/log.do_package.* 2>/dev/null | head -1)

echo "############ do_package log HEAD (first 40 lines after run marker) ############"
grep -n 'perform_packagecopy\|pseudo\|tar\|Bad address\|unknown base' "$CL" 2>/dev/null | head -5
sed -n '1,20p' "$CL"

echo
echo "############ .ko attributes (xattr? size? type?) ############"
KO="$D/image/lib/modules/6.12.62/extra/synaptics_tcm2.ko"
ls -la "$KO" 2>/dev/null
file "$KO" 2>/dev/null
getfattr -d "$KO" 2>/dev/null || echo "(no xattr / getfattr n/a)"

echo
echo "############ image/ tree ############"
find "$D/image" 2>/dev/null

echo
echo "############ is module signing enabled in kernel config? ############"
grep -E 'CONFIG_MODULE_SIG|CONFIG_MODULE_SIG_FORCE' \
  /home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-build-artifacts/.config 2>/dev/null | head

echo
echo "############ reference: how synasdk-drivers-isp packages (stock module class) ############"
cat /home/astra/sdk/meta-synaptics/recipes-kernel/linux-drivers/synasdk-drivers-isp_git.bb | grep -vE '^\s*#' | grep -vE '^\s*$'
