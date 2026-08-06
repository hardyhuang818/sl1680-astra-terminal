#!/bin/bash
cd /home/astra/sdk/meta-webkit || exit 1
echo "=== 1. 切 scarthgap 分支 ==="
git checkout scarthgap 2>&1 | tail -1
grep LAYERSERIES_COMPAT conf/layer.conf
echo "--- 这个分支的版本 ---"
find . -name "*.bb" | grep -E "cog_|wpewebkit_|libwpe_|wpebackend-fdo_" | sort

cd /home/astra/sdk
source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1

echo
echo "=== 2. 解析 ==="
bitbake -p 2>&1 | grep -E "ERROR|WARNING: Layer" | head -5
bitbake-layers show-recipes cog 2>/dev/null | grep -A2 "^cog:" | head -4

echo
echo "=== 3. 开始构建 cog(会连带 wpewebkit, 预计 2~5 小时) ==="
date
nohup bitbake cog > /home/astra/sdk/build-sl1680/cog_build.log 2>&1 &
echo "已后台启动, PID $!"
echo "日志: /home/astra/sdk/build-sl1680/cog_build.log"