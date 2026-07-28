SUMMARY = "TM10.5-TD7800 面板运行时配置（触摸校准 udev 规则）"
DESCRIPTION = "触摸 X 轴镜像校准（LIBINPUT_CALIBRATION_MATRIX）。\
之前是烧完手工写 /etc/udev/rules.d（rootfs 三件套之一），v2.8 起进镜像。"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://99-td7800-touch-cal.rules"
S = "${WORKDIR}"

COMPATIBLE_MACHINE = "(dolphin)"

do_install() {
    install -D -m 0644 ${WORKDIR}/99-td7800-touch-cal.rules \
        ${D}${sysconfdir}/udev/rules.d/99-td7800-touch-cal.rules
}

FILES:${PN} = "${sysconfdir}/udev/rules.d/99-td7800-touch-cal.rules"
