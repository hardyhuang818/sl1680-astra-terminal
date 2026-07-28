#!/bin/sh
echo "=== /etc/astra/llm.conf 结构(key 打码) ==="
sed -e 's/\(sk-[0-9a-f]\{4\}\)[0-9a-zA-Z]*/\1XXXXXXXXXXXXXXXXXXXXXXXXXXXX/' \
    -e 's/\([0-9a-f]\{8\}\)[0-9a-f]\{24\}\.[A-Za-z0-9]*/\1XXXXXXXXXXXXXXXXXXXXXXXX.XXXXXXXXXXXXXXXX/' \
    /etc/astra/llm.conf
echo
echo "=== 权限 ==="
ls -l /etc/astra/llm.conf
