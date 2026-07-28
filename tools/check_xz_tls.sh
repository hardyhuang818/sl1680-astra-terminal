#!/bin/sh
echo "=== astra_xiaozhi 支持 wss:// (TLS) 吗 ==="
n=$(strings /usr/bin/astra_xiaozhi 2>/dev/null | grep -c "wss://")
echo "  wss:// 出现次数: $n"
echo "  链接的库:"
readelf -d /usr/bin/astra_xiaozhi 2>/dev/null | grep NEEDED | sed 's/.*\[\(.*\)\]/    \1/'
echo "  TLS 相关符号:"
strings /usr/bin/astra_xiaozhi 2>/dev/null | grep -iE "openssl|SSL_|TLS_|mbedtls|wolfssl" | head -n 5 | sed 's/^/    /'
echo "  (以上为空 = 客户端不支持加密，只能明文 ws://)"
echo
echo "=== 鉴权呢 ==="
strings /usr/bin/astra_xiaozhi 2>/dev/null | grep -iE "Authorization|Bearer|token|device-id|client-id" | head -n 6 | sed 's/^/    /'
echo
echo "=== 音频参数(决定上行带宽) ==="
strings /usr/bin/astra_xiaozhi 2>/dev/null | grep -oE '"audio_params":\{[^}]*\}' | head -n 1 | sed 's/^/    /'
