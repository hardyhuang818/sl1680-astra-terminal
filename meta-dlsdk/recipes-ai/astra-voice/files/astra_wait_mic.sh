#!/bin/sh
# 等麦克风的 ALSA 声卡出现，再让 astra_voice 启动。
#
# 为什么需要：C920 挂在 1-1.3 上，那条总线会抖（DisplayLink dock 在上面反复重枚举）。
# 实测 2026-07-23：C920 从 USB 上掉了 86 秒才回来，期间 astra_voice 每次启动都
# 「打不开 plughw:CARD=C920,DEV=0 (capture): No such device」退出，
# systemd 每 3 秒重拉一次，**每次都白白重新加载 14-17 秒的模型再死掉**，连崩 7 次。
#
# 加了这一步之后，麦克风不在时就是安静等待，不再空转重载模型。
#
# 用卡【名字】判断而不是卡号：/proc/asound/<NAME> 是按名字建的，
# 而卡号每次开机都会变（实测 C920 时而 card0 时而 card2）。
#
# ⚠️ 光等 /proc/asound/<NAME> 不够 —— 实测(unbind/bind 模拟掉线)卡目录先出现，
#    /dev/snd/ 下的采集节点要等 udev 再建一会儿，中间那个窗口去开会报
#    「打不开 ...(capture): No such file or directory」。所以要等到**采集节点**真出现。
#
# 用法: astra_wait_mic.sh [卡名] [最长等待秒数]
# 退出码恒为 0 —— 超时也不算失败，否则 systemd 会把 unit 判失败又进重启循环，
# 正是我们要消除的行为。真等不到，让 astra_voice 自己去报那句人话错误。

NAME="${1:-C920}"
MAX="${2:-120}"
i=0
said=0

# 卡目录 -> 卡号 -> 采集节点。都拿到才算真的可用。
mic_ready() {
    [ -d "/proc/asound/$NAME" ] || return 1
    idx=$(readlink "/proc/asound/$NAME" 2>/dev/null | sed 's/^card//')
    [ -n "$idx" ] || return 1
    [ -e "/dev/snd/pcmC${idx}D0c" ] || return 1
    return 0
}

while [ "$i" -lt "$MAX" ]; do
    if mic_ready; then
        [ "$i" -gt 0 ] && echo "[wait-mic] $NAME 在第 ${i} 秒就绪 (card${idx}, /dev/snd/pcmC${idx}D0c)"
        # 节点出现到接口真正稳定还有个窗口（dmesg 里能看到枚举后还有一次 reset），
        # 停 2 秒，避免刚出现就去开。
        sleep 2
        exit 0
    fi
    if [ "$said" -eq 0 ]; then
        echo "[wait-mic] 等待声卡 $NAME 就绪（最长 ${MAX}s）..."
        said=1
    fi
    i=$((i + 1))
    sleep 1
done

echo "[wait-mic] 等了 ${MAX}s 仍没等到 $NAME，继续启动（让主程序报错）"
exit 0
