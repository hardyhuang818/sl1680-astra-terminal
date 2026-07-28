#!/bin/bash
cd /home/astra/sdk
source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1
echo "── find-path:"
oe-pkgdata-util find-path /etc/xdg/weston/weston.ini 2>&1 | head -3
echo "── weston-init 包文件:"
oe-pkgdata-util list-pkg-files weston-init 2>/dev/null | head -12
