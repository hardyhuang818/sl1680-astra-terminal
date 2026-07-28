#!/bin/bash
O="/mnt/d/Claude code/Case6_Astra/tools/_wslout"
B=/home/astra/sdk/build-sl1680
A=$B/tmp/work/sl1680-poky-linux/astra-media/1.0

echo "════ image.log 尾部(真正的失败上下文) ════"
tail -n 40 "$O/image.log" 2>/dev/null | cut -c1-200 | sed 's/^/  /'

echo
echo "════ 有没有 pseudo 报错 ════"
grep -iE "pseudo|abort|Aborted|core dumped|Killed" "$O/image.log" 2>/dev/null | head -n 10 | sed 's/^/  /'
ls -t $A/temp/log.do_rootfs* 2>/dev/null | head -n 1 | while read f; do
  grep -iE "pseudo|abort|Killed|out of memory" "$f" | head -n 8 | sed 's/^/  /'
done
echo "  pseudo.log:"
tail -n 12 $A/pseudo/pseudo.log 2>/dev/null | sed 's/^/    /'

echo
echo "════ 内存(OOM 嫌疑) ════"
free -h | sed 's/^/  /'
echo "  WSL 配置的内存上限:"
cat /proc/meminfo | grep -E "MemTotal|SwapTotal" | sed 's/^/    /'
echo "  内核有没有 OOM 记录:"
dmesg 2>/dev/null | grep -iE "oom|killed process" | tail -n 5 | sed 's/^/    /'
echo "    (空 = 没 OOM)"

echo
echo "════ rootfs 到底生成了吗 ════"
ls -d $A/rootfs 2>/dev/null && du -sh $A/rootfs 2>/dev/null | sed 's/^/  /'
echo "  rootfs 里抽查我们的文件:"
for f in usr/bin/astra_voice usr/bin/dl_face usr/lib/libsherpa-onnx-c-api.so usr/bin/astra_wait_mic.sh home/voice/astra_llm.py; do
  [ -e "$A/rootfs/$f" ] && echo "    ✓ $f" || echo "    ✗ $f"
done
