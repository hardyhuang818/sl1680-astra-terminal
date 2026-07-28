#!/bin/sh
# astra_mode —— 双模自动切换看门狗
#
# 逻辑：每 8 秒探一次 PC 服务端(HTTP 8000)。
#   可达   → 云端模式：astra-xiaozhi 跑，astra-voice 停
#   不可达 → 本地模式：astra-voice 跑，astra-xiaozhi 停
# 只在状态变化时动 systemctl，避免反复重启服务。
# 探测必须用 curl -m（限总时长）：busybox wget 的 -T 管不住 connect 阶段挂起
# （SYN 无应答时卡内核重试几分钟），busybox nc 又是无 -w 的极简版。

SERVER=${1:-192.168.5.166}
PORT=${2:-8000}
INTERVAL=8

cur=""
echo "[mode] 双模看门狗启动: 服务端=$SERVER:$PORT"

while :; do
  if curl -m 3 -s -o /dev/null "http://$SERVER:$PORT/" 2>/dev/null; then
    want=cloud
  else
    want=local
  fi

  if [ "$want" != "$cur" ]; then
    if [ "$want" = "cloud" ]; then
      echo "[mode] 服务端可达 → 切云端模式(astra-xiaozhi)"
      systemctl stop astra-voice 2>/dev/null
      systemctl reset-failed astra-xiaozhi 2>/dev/null   # 清掉上次抢麦失败的残留状态
      systemctl start astra-xiaozhi
    else
      echo "[mode] 服务端不可达 → 切本地模式(astra-voice)"
      systemctl stop astra-xiaozhi 2>/dev/null
      systemctl reset-failed astra-voice 2>/dev/null
      systemctl start astra-voice
    fi
    cur=$want
  fi
  sleep $INTERVAL
done
