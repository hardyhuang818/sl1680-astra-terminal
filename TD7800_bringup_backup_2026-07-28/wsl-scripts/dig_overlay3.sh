#!/bin/bash
SDK=/home/astra/sdk
cd "$SDK" || exit 1
KSRC=build-sl1680/tmp/work-shared/sl1680/kernel-source
echo "════ 1. 找 dsi_panel 驱动 (按独特属性名 ACTIVE_WIDTH 搜) ════"
grep -rln "ACTIVE_WIDTH" "$KSRC/drivers" 2>/dev/null | head -5
echo
F=$(grep -rln "ACTIVE_WIDTH" "$KSRC/drivers" 2>/dev/null | head -1)
if [ -n "$F" ]; then
  echo "════ 2. $F 的 command 解析段 ════"
  grep -n -B3 -A30 '"command"' "$F" | head -80
  echo
  echo "════ 3. 0x29/延时/发送方式 相关行 ════"
  grep -n "0x29\|0xff\|delay\|msleep\|usleep\|generic\|GENERIC" "$F" | head -20
fi
echo
echo "════ 4. dolphin-rdk.dts 是否还带 mic 事件的旧改动 ════"
DTS=$(find "$KSRC/arch/arm64/boot/dts" -name "dolphin-rdk.dts" | head -1)
echo "DTS=$DTS"
ls -la "$DTS"* 2>/dev/null
if [ -f "$DTS.orig" ]; then diff "$DTS.orig" "$DTS" && echo "(与.orig无差异,干净)" ; fi
grep -n "bitclock-master\|frame-master" "$DTS" | head -5
echo
echo "════ 5. XLS 表头速览 (装xlrd?) ════"
python3 -c "import xlrd; print('xlrd ok')" 2>&1 | tail -1
