#!/bin/bash
echo "════ 错误原文 ════"
grep -A4 "No recipes" "/mnt/d/Claude code/Case6_Astra/tools/_wslout/v28_kernel.log" | head -8
echo
echo "════ 相关配方真实文件名 ════"
ls /home/astra/sdk/meta-synaptics/recipes-kernel/linux/*.bb 2>/dev/null
ls /home/astra/sdk/poky/meta/recipes-graphics/wayland/weston-init*.bb 2>/dev/null
ls /home/astra/sdk/poky/meta/recipes-extended/timezone/*.bb 2>/dev/null
