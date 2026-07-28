#!/bin/sh
# 设 softvol 音量。softvol 控件"用了才存在" -> 先播一帧静音让它实例化。
aplay -D astraout /home/voice/silent.wav >/dev/null 2>&1
V="${1:-10%}"
case "$V" in *%) ;; *) V="${V}%";; esac
if ! amixer -c dolphinasoc sset AstraVolume "$V" >/dev/null 2>&1; then
    echo "astra_setvol: amixer 设置失败 ($V)" >&2
    exit 1
fi
# 回读核对：报告必须与事实一致(旧版无条件 exit 0，失败也说成功)
amixer -c dolphinasoc sget AstraVolume 2>/dev/null | grep -oE '\[[0-9]+%\]' | head -n 1
