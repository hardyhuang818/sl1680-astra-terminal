#!/bin/sh
echo "=== DRM atomic state (CRTC/plane/fb) ==="
cat /sys/kernel/debug/dri/0/state 2>/dev/null | grep -E "^crtc|^plane|active=|fb=|size=|format=|connector" | head -n 30
echo
echo "=== framebuffers ==="
cat /sys/kernel/debug/dri/0/framebuffer 2>/dev/null | head -n 15
echo
echo "=== vpp/avio 最近日志 ==="
dmesg | grep -i -E "vpp_cmd|VPP_CMD|mipi.*cmd|dsi.*cmd" | tail -n 8
echo
echo "=== 服务状态 ==="
systemctl is-active dl-face astra-voice weston 2>/dev/null
