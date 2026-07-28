#!/bin/bash
cd /home/astra/sdk
B=build-sl1680
echo "════ 谁提供 synap_cli_od ════"
grep -rln "synap_cli_od\|synap-cli" meta-synaptics --include="*.bb" --include="*.bbappend" --include="*.inc" 2>/dev/null | head -n 5 | sed 's|^|  |'
echo "  相关 recipe:"
find meta-synaptics -name "*synap*" -name "*.bb" 2>/dev/null | sed 's|.*/|  |' | head -n 8

echo
echo "════ 人体检测模型(mobilenet224_full1)在哪个包 ════"
grep -rln "object_detection\|mobilenet224" meta-synaptics --include="*.bb" --include="*.inc" 2>/dev/null | head -n 5 | sed 's|^|  |'

echo
echo "════ astra-media 的 dolphin 段已经装了什么(看 synap 在不在) ════"
sed -n '/IMAGE_INSTALL:append:dolphin/,/"/p' meta-synaptics/recipes-bsp/images/astra-media-common.inc | head -n 30 | sed 's/^/  /'

echo
echo "════ python3 的 ssl 在哪个包(astra_llm.py 走 HTTPS) ════"
source poky/oe-init-build-env $B >/dev/null 2>&1
oe-pkgdata-util find-path "*/_ssl*.so" 2>/dev/null | sed 's/^/  /'
oe-pkgdata-util find-path "*/ssl.py" 2>/dev/null | sed 's/^/  /'

echo
echo "════ 板端实际装了哪些 python3 包(反查真实需求) ════"
echo "  (下一步到板上 opkg/dpkg 查)"
