SUMMARY = "DL7400 内容播放器 — 把真实视频/图片送到 DisplayLink 屏"
DESCRIPTION = "回答'视频源从哪来': GStreamer 硬解(v4l2h264dec 等) -> appsink 取帧 -> dlsdk_display_show()。\
支持视频/图片/测试图，持续显示直到 Ctrl+C，退出时干净 teardown 避免设备卡死。"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://dl_player.c"
S = "${WORKDIR}"

DEPENDS = "dlsdk libusb1 gstreamer1.0 gstreamer1.0-plugins-base"
RDEPENDS:${PN} = "dlsdk gstreamer1.0 gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad"

COMPATIBLE_MACHINE = "(dolphin)"

inherit pkgconfig

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} \
        ${WORKDIR}/dl_player.c \
        `pkg-config --cflags --libs gstreamer-1.0 gstreamer-app-1.0` \
        -ldlsdk -lusb-1.0 -lm \
        -o ${B}/dl_player
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${B}/dl_player ${D}${bindir}/dl_player
}
