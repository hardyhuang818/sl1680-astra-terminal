#!/bin/bash
K=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/arch/arm64/boot/dts/synaptics
echo "=== dts 目录里的 dolphin-rdk* ==="
ls -la $K/dolphin-rdk.dts* 2>/dev/null
echo
echo "=== kernel-source 是 git 仓吗 ==="
cd /home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source && git status --short arch/arm64/boot/dts/synaptics/ 2>&1 | head -5
echo
echo "=== 仓库里现有补丁的头部 ==="
head -n 20 "/mnt/d/Claude code/Case6_Astra/meta-dlsdk/recipes-kernel/linux/files/0001-dolphin-rdk-td7800-tm10p5-lvds-panel.patch"
echo "  ... 总行数: $(wc -l < "/mnt/d/Claude code/Case6_Astra/meta-dlsdk/recipes-kernel/linux/files/0001-dolphin-rdk-td7800-tm10p5-lvds-panel.patch")"
echo
echo "=== 备份里有没有基线 dts ==="
ls -la "/mnt/d/Claude code/Case6_Astra/TD7800_bringup_backup_2026-07-28/kernel-dts/" 2>/dev/null
