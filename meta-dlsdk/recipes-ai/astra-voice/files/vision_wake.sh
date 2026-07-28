#!/bin/sh
# vision_wake —— 人走近 → 给 astra_voice 发 SIGUSR1 触发欢迎语
#
# 原理：C920 摄像头常驻出帧 → NPU(people模型)检测 → 框够大(人够近)且持续 → 发信号
# 状态机：来了才触发一次，走了(连续没人)才重新武装 —— 避免有人站着时反复触发
#
# 用法: sh /usr/bin/vision_wake.sh [box阈值%] [持续帧数]
#   box阈值%：人框占画面高度多少算"够近"(默认45)
#   持续帧数：连续几帧满足才触发(默认2，防抖)

MODEL=/usr/share/synap/models/object_detection/people/model/mobilenet224_full1/model.synap
BOX_TH=${1:-45}      # 框高% 阈值
SUSTAIN=${2:-2}      # 需要连续几帧
COOLDOWN=8           # 触发后至少 N 秒不再触发

# 摄像头稳定路径(设备号会变，用 by-id)
BYID=/dev/v4l/by-id/usb-046d_HD_Pro_Webcam_C920-video-index0
VDEV=$(readlink -f "$BYID" 2>/dev/null)
# 开机时 USB 枚举可能慢，最多等 30 秒让 by-id 链接出现（否则会误选到非摄像头节点）
i=0
while [ -z "$VDEV" ] && [ $i -lt 30 ]; do
    sleep 1; i=$((i+1))
    VDEV=$(readlink -f "$BYID" 2>/dev/null)
done
# 再兜底：按 v4l 设备名字找 C920
if [ -z "$VDEV" ]; then
    for d in /dev/video*; do
        n=$(cat /sys/class/video4linux/$(basename $d)/name 2>/dev/null)
        case "$n" in *C920*|*Webcam*) VDEV=$d; break;; esac
    done
fi
[ -z "$VDEV" ] && VDEV=/dev/video3   # 最后兜底

echo "[vwake] 摄像头=$VDEV  框阈值=${BOX_TH}%  持续=${SUSTAIN}帧"

# 清旧 + 启动常驻摄像头管道(保持热，避免每帧冷启动2.3秒)
for p in $(ps aux 2>/dev/null | grep "[g]st-launch.*vw_" | awk '{print $1}'); do kill -9 $p 2>/dev/null; done
rm -f /tmp/vw_*.jpg
gst-launch-1.0 -q v4l2src device=$VDEV ! image/jpeg,width=640,height=480,framerate=5/1 \
  ! multifilesink location=/tmp/vw_%d.jpg max-files=4 post-messages=false > /dev/null 2>&1 &
GPID=$!
sleep 3

armed=1        # 1=可触发  0=已触发等重新武装
hit=0          # 连续够近帧数
miss=0         # 连续没人帧数

trap 'kill -9 $GPID 2>/dev/null; exit 0' INT TERM

while :; do
  sleep 0.5; F=$(ls -t /tmp/vw_*.jpg 2>/dev/null | head -n 1)
  [ -z "$F" ] && { sleep 0.3; continue; }
  OUT=$(synap_cli_od -m $MODEL --score-threshold 0.4 "$F" 2>/dev/null)
  BH=$(echo "$OUT" | grep -A2 '"size"' | grep '"y"' | head -n 1 | grep -oE "[0-9]+")
  if [ -n "$BH" ]; then
    pct=$((BH * 100 / 480))
  else
    pct=0
  fi

  # 心跳日志：每秒左右报一次当前框高(便于观察/标定)
  tick=$((tick+1))
  if [ $((tick % 2)) -eq 0 ]; then
    if [ "$pct" -gt 0 ]; then echo "[vwake] 框高=${pct}% (阈值${BOX_TH}%, armed=$armed)"; fi
  fi

  if [ "$pct" -ge "$BOX_TH" ]; then
    hit=$((hit+1)); miss=0
    if [ "$armed" = "1" ] && [ "$hit" -ge "$SUSTAIN" ]; then
      # 双模：云端客户端(astra_xiaozhi)在跑就唤它，否则唤本地 astra_voice
      PID=$(pgrep -f "/usr/bin/astra_xiaozhi" | head -n 1)
      TGT=astra_xiaozhi
      if [ -z "$PID" ]; then
        PID=$(pgrep -f "/usr/bin/astra_voice" | head -n 1)
        TGT=astra_voice
      fi
      if [ -n "$PID" ]; then
        kill -USR1 "$PID" 2>/dev/null
        echo "[vwake] 有人靠近(框高${pct}%) → 唤醒 ${TGT}(pid $PID)"
      fi
      armed=0
    fi
  else
    hit=0; miss=$((miss+1))
    # 连续没人一段时间 → 重新武装(人走了)
    if [ "$armed" = "0" ] && [ "$miss" -ge 6 ]; then
      armed=1
      echo "[vwake] 人已离开，重新武装"
    fi
  fi
done
