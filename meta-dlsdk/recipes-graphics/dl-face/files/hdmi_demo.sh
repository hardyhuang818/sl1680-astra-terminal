#!/bin/sh
# hdmi_demo.sh —— 在【SL1680 主板自己的 HDMI 口】上跑原生图形界面 demo
#
# ★前提：把显示器插到 SL1680 主板的 HDMI 口(不是 DL7400 的口)。
#   原生 HDMI 走 DRM/KMS 硬件合成，满帧 60fps —— 和 DL7400(USB推像素)是两条路。
#
# 用法:
#   sh /usr/bin/hdmi_demo.sh ai    官方 AI 界面(摄像头→NPU检测→带框显示)  ★推荐
#   sh /usr/bin/hdmi_demo.sh gst   GStreamer NPU 检测叠加(gst-ai)
#   sh /usr/bin/hdmi_demo.sh ui    Qt QML 能力演示界面
#
# 官方逐字确认的 Wayland 环境变量：
export XDG_RUNTIME_DIR=/var/run/user/0
export WESTON_DISABLE_GBM_MODIFIERS=true
export WAYLAND_DISPLAY=wayland-1
export QT_QPA_PLATFORM=wayland
mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"

MODE="${1:-ai}"

# 检查原生 HDMI 接没接屏
HDMI_ST=$(cat /sys/class/drm/card*/card*-HDMI-A-1/status 2>/dev/null | head -n 1)
echo "[hdmi] 原生 HDMI-A-1 状态: ${HDMI_ST:-未知}"
if [ "$HDMI_ST" != "connected" ]; then
  echo "[hdmi] ⚠️ 主板 HDMI 口没检测到显示器！请把屏插到 SL1680 主板自己的 HDMI 口(不是DL7400)。"
fi

# 启 weston(如果没在跑)。weston 需要接了屏的 DRM 输出。
if ! pgrep -x weston >/dev/null 2>&1; then
  echo "[hdmi] 启动 weston 合成器(原生 HDMI)..."
  weston --backend=drm-backend.so --idle-time=0 > /tmp/weston.log 2>&1 &
  sleep 3
fi
if ! pgrep -x weston >/dev/null 2>&1; then
  echo "[hdmi] ❌ weston 没起来。看 /tmp/weston.log。多半是 HDMI 没接屏。"
  tail -n 5 /tmp/weston.log 2>/dev/null | sed 's/^/    /'
  exit 1
fi
echo "[hdmi] weston 运行中"

VDEV=$(readlink -f /dev/v4l/by-id/usb-046d_HD_Pro_Webcam_C920-video-index0 2>/dev/null)
[ -z "$VDEV" ] && VDEV=/dev/video3

case "$MODE" in
  ai|gst)
    # ★实测能跑：gst-ai IC(图像分类)—— 摄像头 → NPU → 原生HDMI 带标签显示
    #   (OD目标检测模式 gst-ai 报 "Unknown app mode"，是 gst-ai 自身 quirk；
    #    syna-ai-player 在本镜像 Qt-wayland 插件加载失败 core dump —— 都待官方修)
    echo "[hdmi] 启动 gst-ai 图像分类 (摄像头 $VDEV → NPU → 原生HDMI)"
    echo "[hdmi] (需先停占摄像头的服务: systemctl stop vision-wake vision-care)"
    gst-ai -a IC -i "$VDEV" -o screen -f /usr/share/gst-ai/ic.json
    ;;
  ui)
    echo "[hdmi] 启动 Qt QML 能力演示界面"
    # qmlscene 或 qt 运行时；板上QML在 /usr/bin
    if command -v qmlscene >/dev/null 2>&1; then
      qmlscene /usr/bin/sl1680-capability-demo.qml 2>/dev/null || qmlscene /usr/bin/main.qml
    else
      qtrenderingserver &
      sleep 2
      echo "  用 qtrenderingserver + QML；具体入口见 /usr/bin/*.qml"
    fi
    ;;
  *)
    echo "用法: sh $0 [ai|gst|ui]"; exit 1
    ;;
esac
