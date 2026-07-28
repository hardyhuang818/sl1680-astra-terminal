#!/bin/bash
# 把烧录包复制到 D:\Claude code\Case6_Astra\flash_image_<日期>\
set -u
S=/home/astra/sdk/build-sl1680/tmp/deploy/images/sl1680
STAMP=$(ls $S/SYNAIMG/TAG--* 2>/dev/null | head -n 1 | sed 's/.*rootfs-\([0-9]*\)--TAG/\1/')
[ -z "$STAMP" ] && STAMP=$(date +%Y%m%d)
DST="/mnt/d/Claude code/Case6_Astra/flash_image_$STAMP"

echo "════ 源 SYNAIMG 内容 ════"
ls -l $S/SYNAIMG/ | awk 'NR>1{printf "  %12s  %s\n",$5,$9}'
echo "  合计: $(du -sh $S/SYNAIMG | cut -f1)"

echo
echo "════ 复制到 $DST ════"
mkdir -p "$DST"
cp -v $S/SYNAIMG/* "$DST/" 2>&1 | tail -n 3 | sed 's/^/  /'

# 附上清单和一份说明
cp $S/astra-media-sl1680.rootfs-*.manifest "$DST/packages.manifest" 2>/dev/null

echo
echo "════ 复制结果 ════"
ls -l "$DST" | awk 'NR>1{printf "  %12s  %s\n",$5,$9}'
echo "  合计: $(du -sh "$DST" | cut -f1)"
