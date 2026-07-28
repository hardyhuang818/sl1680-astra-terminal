#!/bin/bash
# 把本仓库的 meta-dlsdk 接入 Synaptics 官方 Astra SDK（幂等）
# 用法: ./tools/setup_sdk.sh [SDK目录]   (默认 ~/sdk)
set -e
SDK="${1:-$HOME/sdk}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
TAG="scarthgap_6.12_v2.3.0"

[ -d "$SDK" ] || { echo "SDK 目录不存在: $SDK — 先按 SETUP_SDK.md 第 1 步克隆官方 SDK ($TAG)"; exit 1; }
[ -d "$REPO/meta-dlsdk" ] || { echo "找不到 $REPO/meta-dlsdk"; exit 1; }

cd "$SDK"
CUR=$(git describe --tags 2>/dev/null || echo "未知")
[ "$CUR" = "$TAG" ] || echo "⚠️ SDK 版本是 $CUR, 本仓库在 $TAG 上验证过 — 版本漂移风险自负"

# 进构建环境（首次会生成 build-sl1680/conf）
source poky/oe-init-build-env build-sl1680 >/dev/null

if bitbake-layers show-layers 2>/dev/null | grep -q "meta-dlsdk"; then
    echo "meta-dlsdk 已在层列表中 ✓"
else
    bitbake-layers add-layer "$REPO/meta-dlsdk"
    echo "meta-dlsdk 已加入 bblayers.conf ✓"
fi

# DLSDK 二进制自检（NDA 排除件）
M="$REPO/meta-dlsdk/recipes-graphics/dlsdk/BINARIES_MANIFEST.txt"
D="$REPO/meta-dlsdk/recipes-graphics/dlsdk/files"
if [ -f "$M" ]; then
    MISS=0
    while read -r line; do
        f=$(echo "$line" | awk '{print $2}')
        [ -z "$f" ] && continue
        [ -f "$D/$f" ] || { echo "  缺 DLSDK 二进制: $f"; MISS=1; }
    done < <(grep -v "^#" "$M")
    [ $MISS -eq 1 ] && echo "⚠️ 上述文件按 NDA 未入库, 需另行获取放入 $D/（详见 SETUP_SDK.md）" \
                     || echo "DLSDK 二进制齐备 ✓"
fi
echo "完成。构建: cd $SDK && source poky/oe-init-build-env build-sl1680 && bitbake astra-media"
