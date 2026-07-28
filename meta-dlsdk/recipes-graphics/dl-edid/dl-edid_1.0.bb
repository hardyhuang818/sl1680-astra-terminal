SUMMARY = "读 DisplayLink 各输出口的 EDID 和支持模式"
DESCRIPTION = "显示器'无信号'时用来判断是链路问题还是模式问题：\
能读到合法 EDID 说明 DL7400<->显示器 的 DDC/AUX 通道正常(线没问题)；\
模式列表用来挑一个显示器真正支持的分辨率重试。"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://dl_edid.c \
           file://dl_trymode.c \
          "
S = "${WORKDIR}"

DEPENDS = "dlsdk libusb1"
RDEPENDS:${PN} = "dlsdk"
COMPATIBLE_MACHINE = "(dolphin)"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} ${WORKDIR}/dl_edid.c    -ldlsdk -lusb-1.0 -o ${B}/dl_edid
    ${CC} ${CFLAGS} ${LDFLAGS} ${WORKDIR}/dl_trymode.c -ldlsdk -lusb-1.0 -o ${B}/dl_trymode
}
do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${B}/dl_edid    ${D}${bindir}/dl_edid
    install -m 0755 ${B}/dl_trymode ${D}${bindir}/dl_trymode
}
