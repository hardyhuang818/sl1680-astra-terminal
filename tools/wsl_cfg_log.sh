#!/bin/bash
W=/home/astra/sdk/build-sl1680/tmp/work/cortexa73-poky-linux/sherpa-onnx/1.13.4
L=$(ls -t $W/temp/log.do_configure.* 2>/dev/null | head -n 1)
echo "日志: ${L##*/}"
echo "════ 全文前 30 行 ════"
head -n 30 "$L" | sed 's/^/  /'
echo
echo "════ 尾巴 15 行 ════"
tail -n 15 "$L" | sed 's/^/  /'
echo
echo "════ WORKDIR 里到底有没有那些包 ════"
ls $W/*.tar.gz $W/*.zip 2>/dev/null | sed 's|.*/|  |' || echo "  ❌ WORKDIR 根下没有"
echo "  WORKDIR 顶层目录:"
ls $W | sed 's/^/    /'
echo
echo "════ scarthgap 有没有 UNPACKDIR ════"
grep -rn "UNPACKDIR" /home/astra/sdk/poky/meta/conf/*.conf /home/astra/sdk/poky/meta/classes*/base.bbclass 2>/dev/null | head -n 5 | sed 's/^/  /'
echo "  实际取值: $(grep -m1 '^UNPACKDIR=' /tmp/e.txt 2>/dev/null)"
