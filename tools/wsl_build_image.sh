#!/bin/bash
O="/mnt/d/Claude code/Case6_Astra/tools/_wslout"; mkdir -p "$O"

# ★★ 必须先同步整个 layer ★★
# 这一步漏过两次(先是 wsl_sherpa_build.sh，后是这里)，每次都白跑一整轮构建，
# 而且"构建成功"的假象会一路骗到验收环节。--delete-excluded 保证仓库里删掉的
# 文件(比如重复的 bbappend)在构建树里也消失。
R='/mnt/d/Claude code/Case6_Astra/meta-dlsdk'
rsync -a --delete --delete-excluded   --exclude='*.repo_stale_*' --exclude='*.pre_selfheal' --exclude='*.orig' --exclude='*DANGEROUS*'   "$R/" /home/astra/sdk/meta-dlsdk/
echo "layer 已同步"
echo "  astra-media.bbappend 数量: $(find /home/astra/sdk/meta-dlsdk -name 'astra-media.bbappend' | wc -l) (应为 1)"

cd /home/astra/sdk
set +e
source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1
B=/home/astra/sdk/build-sl1680
D=$B/tmp/deploy/images/sl1680

# ★ 先清掉 image 的工作目录：之前几轮残留让 pseudo 的数据库和文件系统对不上
#   (pseudo: path mismatch, 同一 inode 在库里是 A 文件、实际是 B 文件 -> SIGABRT/134)
#   image recipe 没有源码要重新拉，clean 的代价只是重跑 rootfs 组装，
#   10342 个包级任务的 sstate 缓存不受影响。
echo "清理 image 工作目录(修 pseudo 脏状态)..."
bitbake -c clean astra-media > "$O/clean.log" 2>&1
echo "  rc=$?"

echo "开始: $(date '+%H:%M:%S')"
bitbake astra-media > "$O/image.log" 2>&1
RC=$?
echo "结束: $(date '+%H:%M:%S')  rc=$RC"
echo

if [ $RC -ne 0 ]; then
  echo "❌ 镜像构建失败"
  grep -E "^ERROR" "$O/image.log" | head -n 12 | sed 's/^/  /'
  L=$(grep "Logfile of failure stored in:" "$O/image.log" | tail -n 1 | sed 's/.*stored in: //')
  [ -f "$L" ] && { echo "  --- 详情 ---"; tail -n 20 "$L" | cut -c1-200 | sed 's/^/    /'; }
  exit 1
fi

echo "✅✅✅ astra-media 镜像构建成功"
echo "  SYSTEMD_SERVICE:astra-voice = $(bitbake -e astra-voice 2>/dev/null | grep -m1 '^SYSTEMD_SERVICE:astra-voice=' | cut -d\" -f2)"
echo
echo "════ ★ 镜像清单里有没有我们的包 ════"
M=$(ls -t $D/astra-media-sl1680*.manifest 2>/dev/null | head -n 1)
echo "  manifest: ${M##*/}   (共 $(wc -l < "$M") 个包)"
grep -iE "astra-voice|dl-face|sherpa-onnx|dlsdk|packagegroup-astra|ttf-wqy|synasdk-synap" "$M" | sed 's/^/    /'

echo
echo "════ 产出的可烧录文件 ════"
ls -lt $D/ 2>/dev/null | grep -E "astra-media|\.(ext4|tar\.gz|wic|squashfs)" | head -n 10 | awk '{printf "  %12s  %s\n",$5,$9}'

echo
echo "════ rootfs 里确认文件真的在 ════"
RF=$(ls -t $D/astra-media-sl1680*.rootfs.tar.gz 2>/dev/null | head -n 1)
if [ -n "$RF" ]; then
  echo "  从 $(basename $RF) 抽查:"
  tar tzf "$RF" 2>/dev/null | grep -E "usr/bin/astra_voice$|usr/bin/dl_face$|usr/bin/astra_wait_mic|home/voice/astra_llm|libsherpa-onnx-c-api|libonnxruntime|etc/asound.conf|astra-voice.service" | sed 's/^/    /'
else
  echo "  (没有 rootfs.tar.gz，看下面的 IMAGE_FSTYPES)"
  grep -m1 "^IMAGE_FSTYPES" $B/conf/local.conf | sed 's/^/  /'
fi
