#!/bin/sh
# Astra 语音段定时清理 —— 只删累积的语音录音和临时文件，绝不碰模型/程序/配置。
# 由 astra-cleanup.timer 每天调用。
#
# ★安全边界：只删下面白名单里的东西。模型目录(sv/matcha/llm/tts/bin/kws/model)一律不动。

LOG_TAG="astra-cleanup"
freed_before=$(df -m /home | awk 'NR==2{print $4}')

# 1) 语音段调试录音（astra_voice --save-dir 持续在存）
n1=$(ls /home/voice/segs/*.wav 2>/dev/null | wc -l)
rm -f /home/voice/segs/*.wav 2>/dev/null

# 2) /tmp 下的临时语音/图片（各种测试和抓帧留下的）
n2=$(ls /tmp/*.wav /tmp/cam_*.jpg /tmp/p.jpg /tmp/lv.wav 2>/dev/null | wc -l)
rm -f /tmp/*.wav /tmp/cam_*.jpg /tmp/p.jpg /tmp/lv.wav 2>/dev/null

# 3) 视觉抓帧临时文件
rm -f /tmp/frame*.jpg /tmp/q.jpg 2>/dev/null

freed_after=$(df -m /home | awk 'NR==2{print $4}')
freed=$((freed_after - freed_before))

logger -t "$LOG_TAG" "清理完成: 删除 ${n1} 个语音段 + ${n2} 个临时文件, 释放约 ${freed}MB (剩余 ${freed_after}MB)"
echo "[astra-cleanup] 删 ${n1} 语音段 + ${n2} 临时文件, 剩余 ${freed_after}MB /home"
