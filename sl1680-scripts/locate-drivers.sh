#!/bin/bash
KS=~/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source

echo "===== 触摸驱动 (TD7800 / synaptics_tcm2) ====="
echo "-- recipe --"
ls ~/sdk/meta-tcm2-touch/recipes-kernel/linux-drivers/synaptics-tcm2/*.bb 2>/dev/null
echo "-- 源码 (tarball 解包后) --"
ls -d ~/sdk/build-sl1680/tmp/work/sl1680-poky-linux/synaptics-tcm2/*/synaptics_tcm2_touchcomm_tddi_*/source/synaptics_tcm2 2>/dev/null
echo "-- 编译出的 .ko --"
find ~/sdk/build-sl1680/tmp/work/sl1680-poky-linux/synaptics-tcm2 -name 'synaptics_tcm2.ko' 2>/dev/null | grep -v debug | head -3
echo "-- 触摸 DT overlay --"
ls ~/sdk/meta-tcm2-touch/recipes-kernel/linux/files/dolphin-tcm2-touch-overlay.dtso 2>/dev/null

echo
echo "===== 显示驱动 (Synaptics DRM / syna_drm) ====="
echo "-- 显示驱动源码 (内核树内) --"
ls -d "$KS"/drivers/synaptics/soc/berlin/modules/drm 2>/dev/null
echo "-- 关键文件 --"
ls "$KS"/drivers/synaptics/soc/berlin/modules/drm/drm_syna_drv.c 2>/dev/null
ls "$KS"/drivers/synaptics/soc/berlin/modules/drm/panel/panel_dsi.c 2>/dev/null
ls "$KS"/drivers/synaptics/soc/berlin/modules/drm/bridge/ 2>/dev/null
echo "-- 我们加的 LVDS 显示 overlay --"
ls ~/sdk/meta-tcm2-touch/recipes-kernel/linux/files/dolphin-td7800-lvds-overlay.dtso 2>/dev/null
echo "-- base 板级 DTS (dsi_panel 节点) --"
ls "$KS"/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts 2>/dev/null

echo
echo "===== 默认发行版 & WSL 版本 ====="
wsl.exe --version >/dev/null 2>&1 || true
grep -i pretty /etc/os-release 2>/dev/null
