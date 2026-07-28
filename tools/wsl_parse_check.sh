#!/bin/bash
# 用真 bitbake 校验两个新 recipe：语法/依赖/SRC_URI 是否都成立
cd /home/astra/sdk
set +e
source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1

echo "MACHINE=$(grep -E '^MACHINE' conf/local.conf | head -n1)"
echo

echo "════ 1. recipe 能否被 layer 发现 ════"
bitbake-layers show-recipes astra-voice dl-face 2>&1 | grep -vE '^(NOTE|WARNING: Host|Parsing|Loading|Loaded|$)' | head -n 20

echo
echo "════ 2. astra-voice 完整展开(bitbake -e，会暴露一切语法/变量错误) ════"
bitbake -e astra-voice > /tmp/e_astra.txt 2>/tmp/e_astra.err
rc=$?
if [ $rc -ne 0 ]; then
  echo "❌ 解析失败 rc=$rc"
  grep -E 'ERROR|Exception|SyntaxError' /tmp/e_astra.err | head -n 15
else
  echo "✅ 解析通过"
  grep -E '^(SRC_URI|DEPENDS|RDEPENDS:astra-voice|SYSTEMD_SERVICE:astra-voice|COMPATIBLE_MACHINE|S|B)=' /tmp/e_astra.txt | cut -c1-220
fi

echo
echo "════ 3. dl-face 完整展开 ════"
bitbake -e dl-face > /tmp/e_dlface.txt 2>/tmp/e_dlface.err
rc=$?
if [ $rc -ne 0 ]; then
  echo "❌ 解析失败 rc=$rc"
  grep -E 'ERROR|Exception|SyntaxError' /tmp/e_dlface.err | head -n 15
else
  echo "✅ 解析通过"
  grep -E '^(SRC_URI|DEPENDS|RDEPENDS:dl-face|SYSTEMD_SERVICE:dl-face)=' /tmp/e_dlface.txt | cut -c1-220
fi

echo
echo "════ 4. 依赖是否都有 provider(dry-run，最能抓出 RDEPENDS 写错) ════"
bitbake -n astra-voice dl-face > /tmp/n.txt 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  echo "❌ rc=$rc"
  grep -E 'ERROR|Nothing (PROVIDES|RPROVIDES)' /tmp/n.txt | head -n 20
else
  echo "✅ 依赖全部可解析，任务图可生成"
  grep -E 'Tasks Summary|NOTE: Executing' /tmp/n.txt | tail -n 2
fi
