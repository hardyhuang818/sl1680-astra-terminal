#!/bin/bash
cd /home/astra/sdk/meta-webkit || exit 1
echo "=== 远端分支 ==="
git ls-remote --heads origin | awk '{print $2}' | sed 's|refs/heads/||'
echo
echo "=== 找兼容 scarthgap 的历史(需要完整历史) ==="
git fetch --unshallow 2>&1 | tail -1 || git fetch origin 2>&1 | tail -1
# 找最后一个还兼容 scarthgap 的提交
C=$(git log --format=%H -S scarthgap -- conf/layer.conf | head -2 | tail -1)
echo "候选提交(最后包含 scarthgap 的变更点附近): $C"
for c in $(git log --format=%H -20 -- conf/layer.conf); do
  compat=$(git show $c:conf/layer.conf 2>/dev/null | grep LAYERSERIES_COMPAT)
  echo "  ${c:0:9}  $compat"
done