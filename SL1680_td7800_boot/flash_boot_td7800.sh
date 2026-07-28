#!/bin/sh
# SL1680 只刷 boot 分区（TM10.5-TD7800 LVDS 屏点亮），保留 rootfs。板上运行。
# 用法: sh flash_boot_td7800.sh /tmp/boot_td7800.subimg <期望sha256>
set -e
IMG="$1"; SHA="$2"
[ -f "$IMG" ] || { echo "用法: sh flash_boot_td7800.sh <subimg> <sha256>"; exit 1; }

echo "==> 0/5 校验下载文件 sha256"
ACT=$(sha256sum "$IMG" | cut -d' ' -f1)
[ "$ACT" = "$SHA" ] || { echo "sha256 不符! $ACT"; exit 1; }
echo "    OK $ACT"

echo "==> 1/5 备份当前 boot_a/boot_b 到 /home/"
dd if=/dev/mmcblk0p8 of=/home/boot_a_backup_td7800.img bs=1M 2>/dev/null
dd if=/dev/mmcblk0p9 of=/home/boot_b_backup_td7800.img bs=1M 2>/dev/null
sync
ls -l /home/boot_*_backup_td7800.img

echo "==> 2/5 刷 boot_a (mmcblk0p8)"
dd if="$IMG" of=/dev/mmcblk0p8 bs=1M 2>/dev/null
sync

echo "==> 3/5 刷 boot_b (mmcblk0p9)"
dd if="$IMG" of=/dev/mmcblk0p9 bs=1M 2>/dev/null
sync

echo "==> 4/5 回读校验 (按镜像长度截断比对)"
SZ=$(wc -c < "$IMG")
A=$(dd if=/dev/mmcblk0p8 bs=1M 2>/dev/null | head -c "$SZ" | sha256sum | cut -d' ' -f1)
B=$(dd if=/dev/mmcblk0p9 bs=1M 2>/dev/null | head -c "$SZ" | sha256sum | cut -d' ' -f1)
[ "$A" = "$SHA" ] && echo "    boot_a ✓" || { echo "    boot_a 回读不符! $A"; exit 1; }
[ "$B" = "$SHA" ] && echo "    boot_b ✓" || { echo "    boot_b 回读不符! $B"; exit 1; }

echo "==> 5/5 完成。reboot 生效。"
echo "回退命令(出问题时):"
echo "  dd if=/home/boot_a_backup_td7800.img of=/dev/mmcblk0p8 bs=1M; dd if=/home/boot_b_backup_td7800.img of=/dev/mmcblk0p9 bs=1M; sync; reboot"
