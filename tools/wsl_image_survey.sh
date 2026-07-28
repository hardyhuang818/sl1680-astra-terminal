#!/bin/bash
cd /home/astra/sdk
B=build-sl1680
echo "════ Synaptics 提供的 image recipe ════"
find meta-synaptics* -name "*image*.bb" 2>/dev/null | sed 's|^|  |'
echo
echo "════ 其它 layer 里的 image ════"
find . -maxdepth 5 -name "*image*.bb" 2>/dev/null | grep -vE "poky/meta/|poky/meta-selftest|/build" | head -n 15 | sed 's|^\./|  |'
echo
echo "════ 板子上跑的是哪个镜像(反查 os-release / manifest) ════"
ls $B/tmp/deploy/images/sl1680/*.manifest 2>/dev/null | sed 's|.*/|  |'
echo
echo "════ 已经构建过哪些 image(有 rootfs 产物的) ════"
ls -t $B/tmp/deploy/images/sl1680/ 2>/dev/null | grep -E "\.(tar\.gz|ext4|wic|squashfs|rootfs)" | head -n 10 | sed 's/^/  /'
echo "  (空 = 这个构建树没出过完整 rootfs)"
echo
echo "════ astra-media 这个名字在哪 ════"
grep -rln "astra-media" --include="*.bb" --include="*.conf" --include="*.inc" . 2>/dev/null | grep -v "/build" | head -n 6 | sed 's|^\./|  |'
echo
echo "════ IMAGE_INSTALL 相关的现有配置 ════"
grep -rn "IMAGE_INSTALL" $B/conf/local.conf meta-synaptics*/conf/*.conf 2>/dev/null | head -n 8 | sed 's/^/  /'
echo
echo "════ bblayers ════"
grep -E "^\s+/" $B/conf/bblayers.conf | sed 's|.*/sdk/|  |'
