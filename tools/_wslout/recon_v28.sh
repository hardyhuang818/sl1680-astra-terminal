#!/bin/bash
cd /home/astra/sdk
echo "════ 1. weston.ini 属于哪个 recipe ════"
grep -rln "xdg/weston" poky/meta/recipes-graphics/wayland/ meta-synaptics/ 2>/dev/null | grep -vE "\.git|/files/.*\.ini$" | head -5
find poky/meta/recipes-graphics/wayland meta-synaptics -name "weston.ini" 2>/dev/null | head -5
echo
echo "════ 2. deploy 里的整机升级物 (.swu/SYNAIMG) ════"
ls build-sl1680/tmp/deploy/images/sl1680/ | grep -iE "swu|synaimg" | head -8
ls build-sl1680/tmp/deploy/images/sl1680/SYNAIMG/ 2>/dev/null | head -8
echo
echo "════ 3. tzdata recipe 确认 ════"
ls poky/meta/recipes-extended/timezone/ 2>/dev/null
