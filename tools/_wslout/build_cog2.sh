#!/bin/bash
cd /home/astra/sdk/meta-webkit || exit 1
echo "=== 1. 取并切 scarthgap 分支 ==="
git fetch origin scarthgap:scarthgap 2>&1 | tail -1
git checkout scarthgap 2>&1 | tail -1
grep LAYERSERIES_COMPAT conf/layer.conf
echo "--- scarthgap 分支的版本 ---"
find . -name "*.bb" | grep -E "cog_|wpewebkit_|libwpe_|wpebackend-fdo_" | sort

cd /home/astra/sdk
source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1

echo
echo "=== 2. 解析 ==="
P=$(bitbake -p 2>&1 | grep -cE "^ERROR")
if [ "$P" != "0" ]; then
  bitbake -p 2>&1 | grep -E "^ERROR" | head -5
  echo "解析失败，停"
  exit 1
fi
echo "  解析 OK"
bitbake-layers show-recipes cog wpewebkit 2>/dev/null | grep -E "^(cog|wpewebkit):" -A1 | head -8

echo
echo "=== 3. 清掉上次的残尸并启动构建 ==="
for p in $(ps aux | grep "[b]itbake cog" | awk '{print $2}'); do kill $p 2>/dev/null; done
sleep 2
date
nohup bitbake cog > /home/astra/sdk/build-sl1680/cog_build.log 2>&1 &
echo "已后台启动, PID $!"
sleep 60
echo
echo "=== 4. 一分钟后的进度 ==="
tail -5 /home/astra/sdk/build-sl1680/cog_build.log