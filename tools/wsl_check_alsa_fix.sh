#!/bin/bash
R='/mnt/d/Claude code/Case6_Astra/meta-dlsdk'
rsync -a --delete --delete-excluded \
  --exclude='*.repo_stale_*' --exclude='*.pre_selfheal' --exclude='*.orig' --exclude='*DANGEROUS*' \
  "$R/" /home/astra/sdk/meta-dlsdk/
cd /home/astra/sdk
set +e
source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1

echo "════ bbappend 被识别了吗 ════"
bitbake-layers show-appends alsa-state 2>/dev/null | grep -A3 "alsa-state" | sed 's/^/  /'

echo
echo "════ 重建 alsa-state，确认占位文件被删 ════"
bitbake -c cleansstate alsa-state >/dev/null 2>&1
bitbake alsa-state > /tmp/as.log 2>&1
if [ $? -ne 0 ]; then echo "  ❌ 构建失败"; grep -E "^ERROR" /tmp/as.log | head -n 5 | sed 's/^/    /'; exit 1; fi
echo "  ✅ alsa-state 构建通过"
p=$(find /home/astra/sdk/build-sl1680/tmp/deploy/deb -name "alsa-state_*.deb" | head -n 1)
echo "  包内容:"
dpkg -c "$p" 2>/dev/null | awk '{print "    "$6}'
n=$(dpkg -c "$p" 2>/dev/null | grep -c "etc/asound.conf")
[ "$n" -eq 0 ] && echo "  ✅ 占位 asound.conf 已移除(冲突解除)" || echo "  ❌ 还在"

echo
echo "════ 确认 astra-voice 仍然提供它 ════"
p=$(find /home/astra/sdk/build-sl1680/tmp/deploy/deb -name "astra-voice_1.0*.deb" | head -n 1)
dpkg -c "$p" 2>/dev/null | grep asound | sed 's/^/  /'
