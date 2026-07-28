#!/bin/bash
cd /home/astra/sdk
echo "════ layer 里所有和 wqy/zenhei 有关的 recipe ════"
find . -maxdepth 5 -iname '*wqy*' -o -maxdepth 5 -iname '*zenhei*' 2>/dev/null | grep -v '^\./build' | head -n 10
echo
echo "════ 中文字体候选 recipe ════"
find . -path ./build-sl1680 -prune -o -name '*.bb' -print 2>/dev/null | xargs -r grep -l -i 'zenhei\|wenquanyi' 2>/dev/null | head -n 5
echo
echo "════ 板端镜像里装的字体包(从已构建的 rootfs manifest 找) ════"
ls build-sl1680/tmp/deploy/images/*/  2>/dev/null | grep -i manifest | head -n 3
M=$(ls build-sl1680/tmp/deploy/images/*/*.manifest 2>/dev/null | head -n 1)
echo "manifest: $M"
[ -n "$M" ] && grep -i -E 'font|wqy|zenhei|liberation' "$M" | head -n 10
