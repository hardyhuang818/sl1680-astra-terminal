SUMMARY = "Astra 本地语音助手 (VAD + SenseVoice ASR + matcha TTS + 云端 LLM)"
DESCRIPTION = "SL1680 上的常驻语音终端。麦克风(C920)采音 → silero VAD 断句 → \
SenseVoice 中英识别 → astra_llm.py 四层作答(本地音量/本地设备/联网搜索/云端 DeepSeek) \
→ matcha TTS 合成 → ALSA softvol 出声。附带实时中英翻译、视觉唤醒、双模看门狗。\
\
★ 模型不在本 recipe 里 ★ ASR/TTS/LLM 模型合计约 1.9GB，不适合进 git。\
见 files/README_models.md，用 provision-models.sh 单独灌到 /home/voice/。"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://astra_voice.c \
           file://astra_llm.py \
           file://astra_translate.py \
           file://astra_setvol.sh \
           file://astra_wait_mic.sh \
           file://astra_mode.sh \
           file://vision_wake.sh \
           file://vision_care.sh \
           file://astra-cleanup.sh \
           file://silent.wav \
           file://asound.conf \
           file://llm.conf.sample \
           file://astra-voice.service \
           file://astra-translate.service \
           file://astra-mode.service \
           file://vision-wake.service \
           file://astra-cleanup.service \
           file://astra-cleanup.timer \
          "
S = "${WORKDIR}"

DEPENDS = "alsa-lib sherpa-onnx"

# 运行期真实依赖，逐条对应板上实测:
#   alsa-utils   —— amixer(AstraVolume/Mic 增益) + aplay(astra_setvol.sh 预热 softvol)
#   python3-*    —— astra_llm.py / astra_translate.py 只用标准库，但走 HTTPS 要 netclient+ssl
#   curl         —— astra_mode.sh 探测服务端(busybox wget -T 管不住 connect 挂起)
#   gstreamer/v4l—— vision_wake.sh 从 C920 抓帧
#   synap        —— vision_wake.sh 调 synap_cli_od 做人体检测(NPU)
#   synasdk-*    —— vision_wake.sh 调 synap_cli_od 做人体检测，模型也来自 synap
#                   (这两个包碰巧 astra-media 已经装了，但依赖该声明在使用方，
#                    否则换个 image 就会静默失效)
#   python3-io   —— urllib 走 HTTPS 需要 _ssl，它在 python3-io 里不在 python3-netclient
RDEPENDS:${PN} = "alsa-lib alsa-utils sherpa-onnx \
                  python3-core python3-json python3-netclient python3-io \
                  python3-datetime python3-shell python3-threading \
                  curl \
                  gstreamer1.0 gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
                  v4l-utils \
                  synasdk-synap-runtime synasdk-synap-models \
                 "

COMPATIBLE_MACHINE = "(dolphin)"

inherit pkgconfig systemd

# 自启哪些：**对齐板子上实测可用的状态**(2026-07-23 export_live.sh 导出)。
#   vision-wake —— 板上是 enabled 且工作正常。它用的是 C920 的【视频】接口，
#                  astra_voice 用【音频】接口，同一个 USB 设备的两个接口可以并存。
#                  只有 dl_face 切到 camera 模式时才冲突，那时 astra_llm.py 会主动
#                  stop vision-wake，切回来再 start。所以这里必须 enable，
#                  否则烧完的板子"人走近打招呼"是不工作的。
#   astra-cleanup.timer —— 每天 4:00 清语音段，板上 enabled
#
# ⚠️ astra-mode 故意【不】自启：它每 8 秒探测 PC 的 8000 端口，
#    一旦探到就会 stop astra-voice 切云端模式，把无 PC 本地模式掀翻。
#    2026-07-23 已在板上 disable，镜像里也不能自启。
SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE:${PN} = "astra-voice.service astra-translate.service \
                         vision-wake.service astra-cleanup.timer"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

VOICEDIR = "/home/voice"

do_compile() {
    # sherpa-onnx 的 C-API 头以 sherpa-onnx/c-api/c-api.h 形式 include
    ${CC} ${CFLAGS} ${LDFLAGS} \
        ${WORKDIR}/astra_voice.c \
        -I${STAGING_INCDIR} \
        -lsherpa-onnx-c-api -lasound -lpthread -lstdc++ -lm \
        -o ${B}/astra_voice
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${B}/astra_voice            ${D}${bindir}/astra_voice
    install -m 0755 ${WORKDIR}/astra_setvol.sh  ${D}${bindir}/astra_setvol.sh
    install -m 0755 ${WORKDIR}/astra_wait_mic.sh ${D}${bindir}/astra_wait_mic.sh
    install -m 0755 ${WORKDIR}/astra_mode.sh    ${D}${bindir}/astra_mode.sh
    install -m 0755 ${WORKDIR}/vision_wake.sh   ${D}${bindir}/vision_wake.sh
    install -m 0755 ${WORKDIR}/vision_care.sh   ${D}${bindir}/vision_care.sh
    install -m 0755 ${WORKDIR}/astra-cleanup.sh ${D}${bindir}/astra-cleanup.sh

    # 程序里写死 python3 /home/voice/astra_llm.py，别改成 ${bindir}
    install -d ${D}${VOICEDIR}
    install -m 0755 ${WORKDIR}/astra_llm.py       ${D}${VOICEDIR}/astra_llm.py
    install -m 0755 ${WORKDIR}/astra_translate.py ${D}${VOICEDIR}/astra_translate.py
    # softvol 是"用了才存在"的控件: 不先开一次 PCM，amixer 找不到 AstraVolume。
    # astra_setvol.sh 靠放这段无声 wav 来把控件实例化，别删。
    install -m 0644 ${WORKDIR}/silent.wav         ${D}${VOICEDIR}/silent.wav

    install -d ${D}${sysconfdir}
    install -m 0644 ${WORKDIR}/asound.conf ${D}${sysconfdir}/asound.conf

    # API key 走 EnvironmentFile，绝不进镜像。装的是不含 key 的样例。
    install -d ${D}${sysconfdir}/astra
    install -m 0600 ${WORKDIR}/llm.conf.sample ${D}${sysconfdir}/astra/llm.conf.sample

    install -d ${D}${systemd_system_unitdir}
    for u in astra-voice astra-translate astra-mode vision-wake astra-cleanup; do
        install -m 0644 ${WORKDIR}/$u.service ${D}${systemd_system_unitdir}/$u.service
    done
    install -m 0644 ${WORKDIR}/astra-cleanup.timer ${D}${systemd_system_unitdir}/astra-cleanup.timer
}

FILES:${PN} += "${VOICEDIR} \
                ${sysconfdir}/asound.conf \
                ${sysconfdir}/astra \
                ${systemd_system_unitdir} \
               "

# /home/voice 不是标准路径，QA 会报 installed-vs-shipped 之外的目录告警
INSANE_SKIP:${PN} += "ldflags"
