#!/bin/bash
cd /home/astra/sdk
B=build-sl1680
echo "════ deploy/images 里到底有什么 ════"
ls -lt $B/tmp/deploy/images/sl1680/ 2>/dev/null | head -n 18 | awk '{printf "  %10s  %s  %s\n",$5,$6" "$7,$9}'

echo
echo "════ 有哪些 image recipe 可选 ════"
find . -name "core-image-*.bb" -o -name "*-image-*.bb" 2>/dev/null | grep -v "/build" | head -n 12 | sed 's|^\./|  |'

echo
echo "════ 板子上跑的镜像是哪个(从板端 os-release 反查) ════"
echo "  (板端: 需另查)"

echo
echo "════ sstate 里有没有 astra-voice/dl-face 的缓存 ════"
ls $B/../build-sl2619/sstate-cache 2>/dev/null >/dev/null && S=$B/../build-sl2619/sstate-cache || S=$B/sstate-cache
find "$S" -name "*astra-voice*" -o -name "*dl-face*" 2>/dev/null | head -n 5 | sed 's|.*/|  |'
echo "  (空 = 这两个 recipe 从没构建过任何任务)"

echo
echo "════ sherpa-onnx 走到哪一步了 ════"
W=$B/tmp/work/cortexa73-poky-linux/sherpa-onnx/1.13.4/temp
ls $W/log.do_* 2>/dev/null | sed 's|.*/log.do_|  完成: |'
echo "  最后一次日志尾巴:"
tail -n 6 $(ls -t $W/log.do_* 2>/dev/null | head -n 1) 2>/dev/null | sed 's/^/    /'
