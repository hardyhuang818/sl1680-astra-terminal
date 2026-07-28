#!/bin/bash
cd /home/astra/sdk
source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1
echo "════ weston.ini 属于哪个包 ════"
oe-pkgdata-util find-path /etc/xdg/weston/weston.ini 2>&1
echo
echo "════ syna-weston-desktop 装了什么 ════"
oe-pkgdata-util list-pkg-files syna-weston-desktop 2>/dev/null | head -10
echo
echo "════ swu 里有没有动 /home 分区 ════"
cpio -i --to-stdout sw-description < build-sl1680/tmp/deploy/images/sl1680/astra-media.swu 2>/dev/null | grep -cE "home"
