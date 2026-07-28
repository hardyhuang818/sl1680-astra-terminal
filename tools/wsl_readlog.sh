#!/bin/bash
L=$(grep "Logfile of failure stored in:" /tmp/it.txt | tail -n 1 | sed 's/.*stored in: //')
echo "日志: $L"
W=/home/astra/sdk/build-sl1680/tmp/work/cortexa73-poky-linux/sherpa-onnx/1.13.4
[ -f "$L" ] || { echo "  找不到日志"; exit 1; }
echo
echo "════ 命中本地包 ════"
grep "Found local downloaded" "$L" | sed 's|.*downloaded ||' | sed "s|$W/git/|  ✓ |" | sort -u
echo
echo "════ 仍在联网的 ════"
grep -E "^-- Downloading.*https://" "$L" | sed 's/^-- Downloading /  /' | sort -u
echo "  (以上为空 = 全本地)"
echo
echo "════ 失败点 ════"
grep -B1 -A7 "CMake Error" "$L" | head -n 26 | sed "s|$W|<W>|g" | sed 's/^/  /'
grep -E "Could not resolve host|Build step for .* failed" "$L" | sort -u | sed 's/^/  /'
