#!/bin/sh
# 验证 webctl 中/英双路由 + 各 API 仍然可用（英文版 /en 是 TD7800 面板用的 1280x720 排版）
systemctl restart astra-webctl
sleep 2
echo "webctl service : $(systemctl is-active astra-webctl)"
echo "route /   (zh) : $(curl -s -o /dev/null -w '%{http_code} %{size_download}B' http://127.0.0.1:8080/)"
echo "route /en (en) : $(curl -s -o /dev/null -w '%{http_code} %{size_download}B' http://127.0.0.1:8080/en)"
echo "en title       : $(curl -s http://127.0.0.1:8080/en | grep -o 'SL1680 CONSOLE' | head -1)"
echo "en viewport    : $(curl -s http://127.0.0.1:8080/en | grep -o 'width=1280')"
echo "api/status     : $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/api/status)"
echo "api/snapshot   : $(curl -s -o /dev/null -w '%{http_code} %{size_download}B' 'http://127.0.0.1:8080/api/snapshot?t=1')"
echo "--- status json (head) ---"
curl -s http://127.0.0.1:8080/api/status | head -c 300
echo
echo "--- panel mode ---"
cat /sys/class/drm/card0-DSI-1/modes 2>/dev/null | head -3
