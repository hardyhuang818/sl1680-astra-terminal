#!/bin/bash
cd /home/astra/sdk
B=build-sl1680

echo "════ 1. 构建的是哪个 image ════"
grep -nE "^MACHINE|^DISTRO" $B/conf/local.conf | sed 's/^/  /'
echo "  已出的镜像:"
ls -t $B/tmp/deploy/images/sl1680/*.manifest 2>/dev/null | head -n 3 | sed 's|.*/|    |'

echo
echo "════ 2. local.conf 里有没有把我们的包加进镜像 ════"
grep -nE "IMAGE_INSTALL|astra|dl-face|dl_face|CORE_IMAGE_EXTRA" $B/conf/local.conf 2>/dev/null | sed 's/^/  /'
echo "  (空 = 没加)"

echo
echo "════ 3. 全仓搜：有没有任何地方把 astra-voice / dl-face 拉进镜像 ════"
grep -rn "astra-voice\|dl-face" --include="*.bb" --include="*.bbappend" --include="*.conf" --include="*.inc" \
  meta-dlsdk meta-synaptics* $B/conf 2>/dev/null | grep -vE "meta-dlsdk/recipes-(ai/astra-voice|graphics/dl-face)/" | sed 's/^/  /'
echo "  (空 = 没有任何 image/packagegroup 引用它们)"

echo
echo "════ 4. sherpa-onnx 到底编译过没 ════"
W=$B/tmp/work/cortexa73-poky-linux/sherpa-onnx/1.13.4
ls -d $W 2>/dev/null >/dev/null && {
  echo "  work 目录存在，里面有:"
  ls $W | sed 's/^/    /'
  echo "  do_compile 完成标记:"
  ls $W/temp/log.do_compile* 2>/dev/null | sed 's|.*/|    |' || echo "    ❌ 从没跑过 do_compile"
  echo "  image/ (do_install 产物):"
  ls $W/image/usr/lib/libsherpa* 2>/dev/null | sed 's|.*/|    |' || echo "    ❌ 空 = do_install 从没成功"
}

echo
echo "════ 5. 最近一次出的镜像里有没有我们的东西 ════"
M=$(ls -t $B/tmp/deploy/images/sl1680/*.manifest 2>/dev/null | head -n 1)
echo "  manifest: ${M##*/}"
if [ -n "$M" ]; then
  echo "  搜 astra/dl-face/sherpa:"
  grep -iE "astra|dl-face|dlsdk|sherpa" "$M" | sed 's/^/    /' || echo "    ❌ 一个都没有"
  echo "  这个镜像总包数: $(wc -l < "$M")"
fi

echo
echo "════ 6. 有没有 deb/ipk 产出过 ════"
ls $B/tmp/deploy/*/  2>/dev/null | head -n 2
find $B/tmp/deploy -name "astra-voice*" -o -name "dl-face*" -o -name "sherpa-onnx*" 2>/dev/null | head -n 6 | sed 's/^/  /'
echo "  (空 = 从没打包成功过)"
