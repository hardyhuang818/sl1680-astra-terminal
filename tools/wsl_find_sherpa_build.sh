#!/bin/bash
echo "════ WSL 里 libsherpa 的所有副本 ════"
find /home/astra /opt /usr/local -name 'libsherpa-onnx*' 2>/dev/null | grep -v '/sdk/build-sl1680/tmp/work/' | head -n 12
echo
echo "════ 交叉编译用的 sherpa 安装前缀 ════"
find /home/astra -maxdepth 4 -type d -name 'sherpa*' 2>/dev/null | grep -v '/sdk/' | head -n 8
echo
echo "════ 历史命令里怎么编的 astra_voice ════"
grep -h "astra_voice" /home/astra/.bash_history 2>/dev/null | tail -n 6
echo "(空 = 没记录)"
echo
echo "════ 有没有现成的 astra_voice 二进制 ════"
find /home/astra "/mnt/d/Claude code/Case6_Astra" -maxdepth 3 -name 'astra_voice' -type f 2>/dev/null | head -n 5
