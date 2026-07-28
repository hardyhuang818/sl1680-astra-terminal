#!/bin/bash
cd /home/astra/sdk || exit 1
echo "════ SDK 顶层是否 git 仓 ════"
git rev-parse --show-toplevel 2>&1 | head -1
git remote -v 2>/dev/null | head -4
git describe --tags 2>/dev/null; git log --oneline -1 2>/dev/null
echo
echo "════ repo/manifest 痕迹 ════"
ls -d .repo 2>/dev/null && cat .repo/manifests/default.xml 2>/dev/null | head -20
ls *.xml 2>/dev/null | head -5
echo
echo "════ 各子目录的 git 来源 ════"
for d in poky meta-synaptics meta-openembedded base synaptics-sdk; do
  if [ -d "$d/.git" ] || [ -f "$d/.git" ]; then
    echo "-- $d:"
    git -C "$d" remote get-url origin 2>/dev/null
    git -C "$d" describe --tags 2>/dev/null || git -C "$d" log --oneline -1 2>/dev/null
  fi
done
echo
echo "════ 我们动过的 SDK 侧配置 ════"
grep -n "meta-dlsdk" build-sl1680/conf/bblayers.conf 2>/dev/null
grep -n "ASTRA_TERMINAL\|dlsdk" build-sl1680/conf/local.conf 2>/dev/null | head -5
