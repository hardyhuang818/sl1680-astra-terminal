#!/bin/bash
# 把仓库 meta-dlsdk 整层同步到 WSL 构建树，并用真 bitbake 复验
set -e
L=/home/astra/sdk/meta-dlsdk
R='/mnt/d/Claude code/Case6_Astra/meta-dlsdk'
TS=$(date +%Y%m%d-%H%M%S)
B=/tmp/meta-dlsdk-before-$TS.tar.gz

echo "════ 备份 WSL 现有 layer ════"
tar czf "$B" -C /home/astra/sdk meta-dlsdk
echo "  $B  ($(stat -c %s "$B") 字节)"

echo
echo "════ 同步 ════"
# ⚠️ 必须用 --delete-excluded：光 --delete 不会删被 --exclude 排除的文件，
#    上一轮同步进去的留档会一直赖在构建树里。
rsync -a --delete --delete-excluded \
  --exclude='*.repo_stale_*' \
  --exclude='*.pre_selfheal' \
  --exclude='*.orig' \
  --exclude='*DANGEROUS*' \
  "$R/" "$L/"

echo "  留档文件保留在仓库、不进构建树："
find "$R" \( -name '*.repo_stale_*' -o -name '*DANGEROUS*' -o -name '*.pre_selfheal' -o -name '*.orig' \) | sed "s|$R/|    |"
echo "  构建树里残留的留档(应为空)："
find "$L" \( -name '*.repo_stale_*' -o -name '*DANGEROUS*' -o -name '*.pre_selfheal' -o -name '*.orig' \) | sed "s|$L/|    ❌ |"

echo
echo "════ 同步结果 ════"
grep -m1 "^v" "$L/VERSION" | sed 's/^/  版本: /'
echo "  astra-voice files (共 $(ls "$L/recipes-ai/astra-voice/files/" | wc -l) 个):"
ls "$L/recipes-ai/astra-voice/files/" | sed 's/^/    /'

echo
echo "════ 用真 bitbake 复验 ════"
cd /home/astra/sdk
set +e
source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1
bitbake -e astra-voice > /tmp/e1.txt 2>/tmp/e1.err
if [ $? -ne 0 ]; then echo "  ❌ astra-voice 解析失败"; grep ERROR /tmp/e1.err | head -n 6; else
  echo "  ✅ astra-voice 解析通过"
  grep -E '^SRC_URI=' /tmp/e1.txt | tr ' ' '\n' | grep -c "file://" | sed 's/^/     SRC_URI 条目数: /'
  grep -qE 'astra_wait_mic\.sh' /tmp/e1.txt && echo "     ✓ astra_wait_mic.sh 在 SRC_URI 里" || echo "     ❌ astra_wait_mic.sh 不在 SRC_URI"
fi
bitbake -n astra-voice dl-face > /tmp/n1.txt 2>&1
if [ $? -ne 0 ]; then echo "  ❌ 依赖图失败"; grep -E "ERROR|Nothing (PROVIDES|RPROVIDES)" /tmp/n1.txt | head -n 6; else
  echo "  ✅ 依赖图可生成"; grep "Tasks Summary" /tmp/n1.txt | tail -n 1 | sed 's/^/     /'
fi
