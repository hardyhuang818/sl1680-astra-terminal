#!/bin/bash
cd /home/astra/sdk
source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1
echo "════ synap_cli_od 归属哪个包 ════"
oe-pkgdata-util find-path "*/synap_cli_od" 2>/dev/null | sed 's/^/  /'
oe-pkgdata-util find-path "*/bin/synap_cli*" 2>/dev/null | head -n 5 | sed 's/^/  /'

echo
echo "════ 人体检测模型归属哪个包 ════"
oe-pkgdata-util find-path "*/object_detection/people/*" 2>/dev/null | head -n 4 | sed 's/^/  /'
oe-pkgdata-util find-path "*mobilenet224*" 2>/dev/null | head -n 4 | sed 's/^/  /'

echo
echo "════ PLATYPUS_DOLPHIN_INSTALL 里有什么 ════"
bitbake -e astra-media 2>/dev/null | grep -m1 "^PLATYPUS_DOLPHIN_INSTALL=" | tr ' ' '\n' | grep -vE '^"?$' | sed 's/^/  /' | head -n 25

echo
echo "════ astra-media 最终 IMAGE_INSTALL 里有没有 synap ════"
bitbake -e astra-media 2>/dev/null | grep -m1 "^IMAGE_INSTALL=" | tr ' ' '\n' | grep -iE "synap|wqy|alsa|python3" | sort -u | sed 's/^/  /'
