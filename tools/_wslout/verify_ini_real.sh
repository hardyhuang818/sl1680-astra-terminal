#!/bin/bash
E=/home/astra/sdk/build-sl1680/tmp/deploy/images/sl1680/astra-media-sl1680.rootfs.ext4
echo "── weston.ini.weston-init 里的翻转配置:"
debugfs -R "cat /etc/xdg/weston/weston.ini.weston-init" "$E" 2>/dev/null | tail -8
echo
echo "── grep rotate-180:"
debugfs -R "cat /etc/xdg/weston/weston.ini.weston-init" "$E" 2>/dev/null | grep -c "rotate-180"
