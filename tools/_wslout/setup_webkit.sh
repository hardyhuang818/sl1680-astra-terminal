#!/bin/bash
cd /home/astra/sdk || exit 1
echo "=== 1. 取 meta-webkit ==="
if [ ! -d meta-webkit ]; then
  git clone --depth 1 https://github.com/Igalia/meta-webkit.git 2>&1 | tail -2
fi
[ -d meta-webkit ] || { echo "克隆失败"; exit 1; }
echo "--- 层兼容性声明 ---"
grep -n "LAYERSERIES_COMPAT" meta-webkit/conf/layer.conf
echo "--- 有哪些 recipe ---"
find meta-webkit -name "*.bb" | grep -E "cog|wpewebkit|libwpe|wpebackend" | sort

echo
echo "=== 2. 接层 ==="
source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1
grep -q meta-webkit conf/bblayers.conf || \
  sed -i 's|  /home/astra/sdk/meta-tcm2-touch |  /home/astra/sdk/meta-webkit \\\n  /home/astra/sdk/meta-tcm2-touch |' conf/bblayers.conf
grep -E "meta-webkit|meta-tcm2" conf/bblayers.conf

echo
echo "=== 3. 解析测试(不真正构建) ==="
bitbake -p 2>&1 | tail -3
bitbake-layers show-recipes cog wpewebkit 2>/dev/null | grep -A2 -E "^cog|^wpewebkit"
