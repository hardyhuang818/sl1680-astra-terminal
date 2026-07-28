#!/bin/bash
A=/home/astra/sdk/build-sl1680/tmp/work/sl1680-poky-linux/astra-media/1.0
L=$(ls -t $A/temp/log.do_rootfs.[0-9]* 2>/dev/null | head -n 1)
echo "日志: ${L##*/}"
echo
echo "════ astra-voice 附近的 20 行(真正的原因) ════"
grep -n -B4 -A16 "astra-voice" "$L" | grep -vE "^\s*[0-9]+-\s*dpkg: warning: (package architecture|overriding)" | head -n 40 | sed 's/^/  /'
echo
echo "════ 所有 dpkg 错误行 ════"
grep -E "^dpkg: error|trying to overwrite|conflicts with|different from other instances|E: " "$L" | sort -u | head -n 15 | sed 's/^/  /'
echo
echo "════ astra-voice deb 里的文件(找冲突嫌疑) ════"
dpkg -c $A/oe-rootfs-repo/cortexa73/astra-voice_1.0-r0_arm64.deb 2>/dev/null | awk '{print "  "$6}'
echo
echo "════ /etc/asound.conf 还有谁装(经典冲突) ════"
cd /home/astra/sdk && source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1
oe-pkgdata-util find-path "/etc/asound.conf" 2>/dev/null | sed 's/^/  /'
