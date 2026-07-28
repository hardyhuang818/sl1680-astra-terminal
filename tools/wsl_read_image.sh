#!/bin/bash
M=/home/astra/sdk/meta-synaptics/recipes-bsp/images
echo "════ astra-media.bb ════"
cat $M/astra-media.bb 2>/dev/null | sed 's/^/  /'
echo
echo "════ astra-media-common.inc (前 60 行) ════"
head -n 60 $M/astra-media-common.inc 2>/dev/null | sed 's/^/  /'
echo
echo "════ IMAGE_INSTALL / IMAGE_FEATURES 定义在哪 ════"
grep -n "IMAGE_INSTALL\|IMAGE_FEATURES\|IMAGE_FSTYPES" $M/*.inc $M/*.bb 2>/dev/null | sed 's|.*/images/|  |'
