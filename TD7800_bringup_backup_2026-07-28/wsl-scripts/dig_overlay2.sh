#!/bin/bash
SDK=/home/astra/sdk
cd "$SDK" || exit 1
KSRC=$(ls -d build-sl1680/tmp*/work-shared/*/kernel-source 2>/dev/null | head -1)
echo "KSRC=$KSRC"
echo
echo "════ 1. dsi_panel 驱动文件 ════"
DSIP=$(grep -rln "dsi_panel\|DSI_PANEL" "$KSRC/drivers/gpu/drm/syna" 2>/dev/null | head -8)
echo "$DSIP"
echo
echo "════ 2. command 属性解析代码 ════"
for f in $(grep -rln '"command"' "$KSRC/drivers/gpu/drm/syna" 2>/dev/null | head -3); do
  echo "--- $f:"
  grep -n -B2 -A25 '"command"' "$f" | head -70
done
echo
echo "════ 3. power-supply/backlight 是否可选 ════"
grep -rn "power-supply\|backlight" $DSIP 2>/dev/null | head -10
echo
echo "════ 4. 我们的 td7800 dtbo 编译产物 ════"
fdtdump build-sl1680/tmp/deploy/images/sl1680/dolphin-td7800-lvds-overlay.dtbo 2>/dev/null | sed -n '12,70p'
echo
echo "════ 5. linux-syna.inc 的 dtbo 处理段 ════"
sed -n '15,30p;60,80p' meta-synaptics/recipes-kernel/linux/linux-syna.inc
echo
echo "════ 6. bootloader 侧谁 apply overlay ════"
ls meta-synaptics/recipes-bsp/ 2>/dev/null
grep -rn "overlay\|dtbo" meta-synaptics/recipes-bsp/ 2>/dev/null | grep -v Binary | head -15
echo "--- deploy 里的 boot 相关:"
ls build-sl1680/tmp/deploy/images/sl1680/ 2>/dev/null | grep -iE "boot|subimg|dtb$" | head -15
