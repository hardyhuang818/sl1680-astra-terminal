#!/bin/bash
O="/mnt/d/Claude code/Case6_Astra/tools/_wslout"
R='/mnt/d/Claude code/Case6_Astra/meta-dlsdk'
echo "★ 同步 layer"
rsync -a --delete --delete-excluded --exclude='.git' --exclude='*.orig' \
  --exclude='*DANGEROUS*' "$R/" /home/astra/sdk/meta-dlsdk/
grep -c "不要.*在这里拦" /home/astra/sdk/meta-dlsdk/recipes-ai/astra-voice/files/astra_voice.c \
  && echo "  源码补丁已同步"

cd /home/astra/sdk
set +e
source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1
echo "★ 重建 astra-voice ($(date +%H:%M:%S))"
bitbake -c cleansstate astra-voice > "$O/av_clean.log" 2>&1
bitbake astra-voice > "$O/av_build.log" 2>&1
RC=$?
echo "  rc=$RC ($(date +%H:%M:%S))"
if [ $RC -ne 0 ]; then
  grep -E "^ERROR" "$O/av_build.log" | head -n 6
  L=$(grep "Logfile of failure stored in:" "$O/av_build.log" | tail -1 | sed 's/.*stored in: //')
  [ -f "$L" ] && tail -n 15 "$L" | cut -c1-160
  exit 1
fi
B=$(find build-sl1680/tmp/work -path "*astra-voice*" -name astra_voice -type f -newermt "-30 minutes" 2>/dev/null | grep -v "\.debug" | head -n 1)
echo "★ 产物: $B"
ls -la "$B"
echo "★ 验证旧字符串已消失"
grep -ac "没有联网，查不到实时天气" "$B" 2>/dev/null && echo "  ✗ 旧规则还在!" || echo "  √ 旧规则已删除"
cp "$B" "/mnt/d/Claude code/Case6_Astra/SL1680_td7800_boot/astra_voice_v28"
sha256sum "$B" | cut -c1-72
