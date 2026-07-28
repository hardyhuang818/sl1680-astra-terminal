#!/bin/sh
# vision_care —— 智能看护 demo：C920 + NPU 人体检测 → 事件规则 → 语音告警
#
# 检测三类事件(在你已跑通的人体检测上加时间/形状规则，几乎零新技术)：
#   1. 滞留过久  人连续在画面里超过 LOITER 秒     → "有人长时间停留"
#   2. 区域离开  人消失超过 LEAVE 秒(之前在)       → "监护区域已无人"
#   3. 疑似跌倒  检测框【宽>高】(人躺倒了)          → "疑似跌倒，请注意"(简单启发式)
#
# 触发方式：把告警语写到 /tmp/astra_say.txt，给 astra_voice 发 SIGUSR2 播报。
#
# 用法: sh /usr/bin/vision_care.sh [滞留秒] [离开秒]

MODEL=/usr/share/synap/models/object_detection/people/model/mobilenet224_full1/model.synap
LOITER=${1:-15}     # 滞留告警阈值(秒)
LEAVE=${2:-6}       # 离开告警阈值(秒)

BYID=/dev/v4l/by-id/usb-046d_HD_Pro_Webcam_C920-video-index0
VDEV=$(readlink -f "$BYID" 2>/dev/null); [ -z "$VDEV" ] && VDEV=/dev/video3
echo "[care] 摄像头=$VDEV  滞留告警=${LOITER}s  离开告警=${LEAVE}s"

say() {   # 让 Astra 播报一句
  echo "$1" > /tmp/astra_say.txt
  PID=$(pgrep -f "/usr/bin/astra_voice" | head -n 1)
  [ -n "$PID" ] && kill -USR2 "$PID" 2>/dev/null
  echo "[care] 告警: $1"
}

# 常驻摄像头管道(保持热)
for p in $(ps aux 2>/dev/null | grep "[g]st-launch.*vc_" | awk '{print $1}'); do kill -9 $p 2>/dev/null; done
rm -f /tmp/vc_*.jpg
gst-launch-1.0 -q v4l2src device=$VDEV ! image/jpeg,width=640,height=480,framerate=10/1 \
  ! multifilesink location=/tmp/vc_%d.jpg max-files=4 post-messages=false > /dev/null 2>&1 &
GPID=$!
sleep 3
trap 'kill -9 $GPID 2>/dev/null; exit 0' INT TERM

present=0            # 当前是否有人
since=0             # 有人起始时间(秒)
absent_since=0      # 无人起始时间
loiter_alerted=0    # 滞留已告警(避免重复)
leave_alerted=0
fall_alerted=0

now() { awk '{print int($1)}' /proc/uptime; }

while :; do
  F=$(ls -t /tmp/vc_*.jpg 2>/dev/null | head -n 1)
  [ -z "$F" ] && { sleep 0.3; continue; }
  OUT=$(synap_cli_od -m $MODEL --score-threshold 0.4 "$F" 2>/dev/null)
  N=$(echo "$OUT" | grep -c '"class_index"')
  BW=$(echo "$OUT" | grep -A2 '"size"' | grep '"x"' | head -n 1 | grep -oE "[0-9]+")
  BH=$(echo "$OUT" | grep -A2 '"size"' | grep '"y"' | head -n 1 | grep -oE "[0-9]+")
  T=$(now)

  if [ "$N" -ge 1 ]; then
    # 有人
    if [ "$present" = "0" ]; then
      present=1; since=$T; absent_since=0; loiter_alerted=0; leave_alerted=0; fall_alerted=0
      echo "[care] 有人进入监护区"
    fi
    dur=$((T - since))
    # 滞留
    if [ "$dur" -ge "$LOITER" ] && [ "$loiter_alerted" = "0" ]; then
      say "监护提醒，有人已在此停留超过${LOITER}秒，请注意。"
      loiter_alerted=1
    fi
    # 疑似跌倒：框宽明显大于高(人躺倒)
    if [ -n "$BW" ] && [ -n "$BH" ] && [ "$fall_alerted" = "0" ]; then
      if [ "$BW" -gt "$((BH * 12 / 10))" ]; then
        say "注意，检测到疑似跌倒，请及时查看。"
        fall_alerted=1
      fi
    fi
  else
    # 无人
    if [ "$present" = "1" ]; then
      present=0; absent_since=$T
      echo "[care] 人离开画面"
    fi
    if [ "$absent_since" != "0" ]; then
      gone=$((T - absent_since))
      if [ "$gone" -ge "$LEAVE" ] && [ "$leave_alerted" = "0" ]; then
        say "监护区域已无人。"
        leave_alerted=1
      fi
    fi
  fi
done
