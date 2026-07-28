#!/bin/bash
echo "════ bblayers.conf ════"
grep -vE "^#|^$" /home/astra/sdk/build-sl1680/conf/bblayers.conf | tail -n 12
echo
echo "════ WSL 里的 meta-tcm2-touch ════"
ls -d /home/astra/sdk/meta-tcm2-touch 2>/dev/null && \
  find /home/astra/sdk/meta-tcm2-touch -name "*.bb" -o -name "*.patch" | head -6
echo
echo "════ 已构建的驱动源码位置 ════"
find /home/astra/sdk/build-sl1680/tmp/work -path "*synaptics-tcm2*" -name "syna_tcm2.h" 2>/dev/null | head -2
