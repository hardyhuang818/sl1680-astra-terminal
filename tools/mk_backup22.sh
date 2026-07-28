#!/bin/sh
set -u
VER="v2.2"
DATE="2026-07-23"
STAMP="${DATE}_1810"
D=/home/backup_${STAMP}
rm -rf $D; mkdir -p $D/usr_bin $D/home_voice $D/etc $D/systemd

echo "=== 收集板上文件 ==="
for f in dl_face vision_wake.sh astra_setvol.sh; do
  cp /usr/bin/$f $D/usr_bin/ 2>/dev/null && echo "  usr/bin/$f"
done
for f in astra_llm.py astra_translate.py silent.wav; do
  cp /home/voice/$f $D/home_voice/ 2>/dev/null && echo "  home/voice/$f"
done
cp /etc/asound.conf $D/etc/ 2>/dev/null && echo "  etc/asound.conf"
sed 's/=.*/=<REDACTED>/' /etc/astra/llm.conf > $D/etc/llm.conf.redacted && echo "  etc/llm.conf (脱敏)"
for s in astra-voice astra-mode astra-translate dl-face vision-wake; do
  cp /etc/systemd/system/$s.service $D/systemd/ 2>/dev/null && echo "  systemd/$s.service"
done

echo
echo "=== 生成版本信息 ==="
# 视频设备清单先算好(heredoc 里嵌套命令替换会踩语法坑)
VIDLIST=$(for d in /dev/video*; do
            n=$(cat /sys/class/video4linux/$(basename "$d")/name 2>/dev/null)
            echo "  $d = $n"
          done)
cat > $D/VERSION.txt <<EOF
╔══════════════════════════════════════════════════════════╗
║  SL1680 语音终端 配置备份                                ║
║                                                          ║
║     版 本 : ${VER}                                         ║
║     日 期 : ${DATE}                                     ║
║     时 间 : $(date '+%H:%M:%S %Z')                              ║
╚══════════════════════════════════════════════════════════╝

内核: $(uname -r)
备份时开机时长: $(uptime | sed 's/.*up//;s/,.*//')

════════ 本版新增(相对 v2.1) ════════
· 语音指令「重新检测屏幕/屏幕不亮/刷新屏幕」-> 重启 dl-face 重新枚举
  (便携屏断电后唯一安全的恢复方式; 四种自动检测手段实测全部不可用)
· astra_llm.py 增加 _rescan_screens()
· 三个 DLSDK 诊断工具源码(在仓库 meta-dlsdk/.../):
    dl_hptest.c    - 测 libusb 热插拔能力 + dlsdk 热插拔注册
    dl_dptest.c    - 探 EDID / preferred_mode / dpaux_read / dpaux_detect
    dl_frametest.c - 测推帧路径 show/wait_on_show 能否区分黑屏
· DisplayLink 问题报告(中英双语): DisplayLink_Issue_Report_${DATE}.md

════════ 关键参数 ════════
[采音]
  --min-rms   $(grep -o -- '--min-rms [0-9]*' /etc/systemd/system/astra-voice.service | cut -d' ' -f2)
  --min-dur   $(grep -o -- '--min-dur [0-9.]*' /etc/systemd/system/astra-voice.service | cut -d' ' -f2)
  --pad-front $(grep -o -- '--pad-front [0-9.]*' /etc/systemd/system/astra-voice.service | cut -d' ' -f2)
  --gain      $(grep -o -- '--gain [0-9.]*' /etc/systemd/system/astra-voice.service | cut -d' ' -f2)
[显示]
  dl_face fps $(grep -o -- '--fps [0-9]*' /etc/systemd/system/dl-face.service | cut -d' ' -f2)
  开机延迟    $(grep -o 'sleep [0-9]*' /etc/systemd/system/dl-face.service | cut -d' ' -f2) 秒
[视觉]
  采集帧率    $(grep -o 'framerate=[0-9]*/1' /usr/bin/vision_wake.sh | head -n 1)
[音量]
  开机默认    $(grep -o 'astra_setvol.sh [0-9]*%' /etc/systemd/system/astra-voice.service | cut -d' ' -f2)

════════ astra_llm.py 能力(每项应 >=1) ════════
$(for k in try_volume try_device needs_search _screen_count _SHORT_CMD _rescan_screens; do
    printf "  %-18s %s 处\n" "$k" "$(grep -c "$k" /home/voice/astra_llm.py)"
  done)

════════ 运行时状态 ════════
$(for s in astra-voice astra-mode astra-translate dl-face vision-wake; do
    printf "  %-18s active=%-9s enabled=%s\n" "$s" "$(systemctl is-active $s)" "$(systemctl is-enabled $s)"
  done)

声卡:
$(cat /proc/asound/cards | sed 's/^/  /')

视频设备:
${VIDLIST}

显示器(本次开机):
$(journalctl -u dl-face --no-pager -b -o cat 2>/dev/null | grep -E "发现|屏点亮" | tail -n 4 | sed 's/^/  /')

DisplayLink:
  固件 $(dmesg 2>/dev/null | grep -o "bcdDevice=[0-9.]*" | head -n 1)
  dock $(lsusb 2>/dev/null | grep -i displaylink | sed 's/^ *//')

════════ 已知限制 ════════
· 便携屏断电后【不会自动点亮】—— SDK 四种检测手段实测全部不可用,
  详见 DisplayLink_Issue_Report。恢复方式: 语音说「屏幕不亮」。
· 摄像头 C920 独占: dl_face camera 模式与 vision-wake 只能二选一。
· /tmp/astra_screen_mode.txt 在 tmpfs, 重启丢失 -> 回到双表情脸(期望默认)。
· 嘈杂环境需靠近麦克风说话(说话 RMS 与底噪重叠, 根治需 KWS 唤醒词)。
EOF
echo "  VERSION.txt"

echo
echo "=== 打包 ==="
cd /home && tar czf backup_${STAMP}.tar.gz backup_${STAMP}
ls -l /home/backup_${STAMP}.tar.gz
echo -n "sha256: "; sha256sum /home/backup_${STAMP}.tar.gz | cut -d' ' -f1
echo
cat $D/VERSION.txt
