#!/bin/bash
set -e
L=/home/astra/sdk/meta-dlsdk
R='/mnt/d/Claude code/Case6_Astra/meta-dlsdk'
TS=$(date +%Y%m%d-%H%M%S)
B=/tmp/meta-dlsdk-backup-$TS.tar.gz

echo "--- 同步前 ---"
ls -d $L/recipes-ai/astra-voice $L/recipes-graphics/dl-face 2>/dev/null || echo "  (两个目录都不存在)"

tar czf "$B" -C /home/astra/sdk meta-dlsdk
echo "备份: $B  ($(stat -c %s "$B") 字节)"

mkdir -p $L/recipes-ai/astra-voice $L/recipes-graphics/dl-face
rsync -a --delete "$R/recipes-ai/astra-voice/"      $L/recipes-ai/astra-voice/
rsync -a --delete "$R/recipes-graphics/dl-face/"    $L/recipes-graphics/dl-face/

echo "--- 同步后 layer 里的 recipe ---"
find $L -name '*.bb' | sort | sed 's|.*/meta-dlsdk/|  |'
echo "--- 排除掉不该进构建的留档文件 ---"
find $L -name '*.repo_stale_*' -o -name '*DANGEROUS*' -o -name '*.pre_selfheal' -o -name '*.orig' | sed 's|.*/meta-dlsdk/|  |'
