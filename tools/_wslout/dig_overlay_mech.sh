#!/bin/bash
# 挖掘: U-Boot overlay 机制 + dsi_panel 驱动 init 命令支持 + FIT 结构
SDK=/home/astra/sdk
OUT=/mnt/d/Claude\ code/Case6_Astra/tools/_wslout
cd "$SDK" || { echo "SDK dir missing"; exit 1; }

echo "════ 1. 找 U-Boot / boot 脚本里的 dtbo 逻辑 ════"
# u-boot 源码位置
UBOOT=$(find build*/tmp*/work -maxdepth 4 -type d -name "u-boot*" 2>/dev/null | head -3)
echo "u-boot dirs: $UBOOT"
# 机制关键词: dtbo / overlay / fdt apply
for d in $UBOOT; do
  find "$d" -name "*.c" -o -name "*.h" -o -name "*.env" -o -name "*.cfg" 2>/dev/null | head -5
done
grep -rn "dtbo" --include="*.bb" --include="*.bbclass" --include="*.inc" --include="*.conf" meta-synaptics/ 2>/dev/null | grep -v "^Binary" | head -20
echo
echo "════ 2. SYNA_KERNEL_DTBO_FILE 怎么被消费 ════"
grep -rn "SYNA_KERNEL_DTBO" --include="*.bb*" --include="*.inc" --include="*.conf" --include="*.py" --include="*.sh" meta-synaptics/ meta-dlsdk/ 2>/dev/null | head -15
echo
echo "════ 3. FIT 组装脚本 (its 文件/gen_secure) ════"
find meta-synaptics -name "*.its*" 2>/dev/null | head -5
grep -rln "fit\|\.its" meta-synaptics/recipes-kernel/ 2>/dev/null | head -10
echo
echo "════ 4. kernel: dsi_panel 驱动在哪, 支持什么属性 ════"
KSRC=$(ls -d build*/tmp*/work-shared/dolphin/kernel-source 2>/dev/null | head -1)
echo "KSRC=$KSRC"
if [ -n "$KSRC" ]; then
  DSIP=$(grep -rln "dsi_panel" "$KSRC/drivers/gpu/drm/" 2>/dev/null | head -5)
  echo "dsi_panel 相关文件:"; echo "$DSIP"
  # 找解析的 DT 属性名
  for f in $DSIP; do
    echo "--- $f 里的 of_property/command 关键行:"
    grep -n "of_property_read\|of_get_property\|command\|COMMAND" "$f" 2>/dev/null | head -25
  done
fi
echo
echo "════ 5. 官方面板 overlay 的 DT schema (ws-panel 为样本) ════"
DTBO=$(find build*/tmp*/deploy -name "dolphin-ws-panel-overlay.dtbo" 2>/dev/null | head -1)
[ -z "$DTBO" ] && DTBO=$(find "$KSRC/../" -name "dolphin-ws-panel-overlay.dtbo" 2>/dev/null | head -1)
echo "dtbo=$DTBO"
if [ -n "$DTBO" ] && command -v fdtdump >/dev/null; then
  fdtdump "$DTBO" 2>/dev/null | head -80
else
  # 找 .dts 源更好
  find "$KSRC/arch/arm64/boot/dts" -name "*ws-panel*" 2>/dev/null
  SRC=$(find "$KSRC/arch/arm64/boot/dts" -name "*ws-panel-overlay*" ! -name "*1080*" 2>/dev/null | head -1)
  [ -n "$SRC" ] && sed -n '1,80p' "$SRC"
fi
