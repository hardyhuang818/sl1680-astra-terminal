SUMMARY = "SL1680 + DL7400 多屏验证/吞吐实测 demo"
DESCRIPTION = "枚举 DisplayLink 设备与所有 display，逐屏点亮并推动态画面，实测 fps / MB/s。\
用来回答 'SL1680 到底能带几个屏、什么分辨率、多少帧'。"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://dl_multiscreen_demo.c"
S = "${WORKDIR}"

DEPENDS = "dlsdk libusb1"
RDEPENDS:${PN} = "dlsdk"

COMPATIBLE_MACHINE = "(dolphin)"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} \
        ${WORKDIR}/dl_multiscreen_demo.c \
        -ldlsdk -lusb-1.0 -lm \
        -o ${B}/dl_multiscreen_demo
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${B}/dl_multiscreen_demo ${D}${bindir}/dl_multiscreen_demo
}
