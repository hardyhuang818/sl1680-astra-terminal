SUMMARY = "DL7400 表情脸 + 中英双语实时字幕"
DESCRIPTION = "在 DisplayLink 屏上显示可爱表情脸，并把 astra-voice 的识别结果和回答 \
以中英对照字幕实时打上去。支持双屏分角色(一块脸/一块 C920 画面)，角色由 \
/tmp/astra_screen_mode.txt 控制，可用语音切换。\
\
★ 已知限制 ★ 本板 dlsdk_register_hotplug_callback 恒返回 UNSUCCESSFUL，\
显示器断电再上电不会自动点亮，需重启本服务重新枚举。详见 \
DisplayLink_Issue_Report_2026-07-23.md。切勿把 dlsdk_dpaux_read 轮询加回主循环 —— \
实测会让同一 device 上所有输出一起黑屏(见 files/dl_face.c.DANGEROUS_dpaux_DO_NOT_BUILD)。"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://dl_face.c \
           file://dl-face.service \
          "
S = "${WORKDIR}"

DEPENDS = "dlsdk libusb1 gstreamer1.0 gstreamer1.0-plugins-base"

# textoverlay(pango) 在 -good；videotestsrc/appsink 在 -base；
# v4l2src(摄像头角色)在 -good。
# 中文字幕必须有"WenQuanYi Zen Hei"这个 fontconfig 家族名，缺了整屏方框；
# 提供它的 recipe 在 meta-openembedded/meta-oe，包名是 ttf-wqy-zenhei(不是 wqy-zenhei)。
RDEPENDS:${PN} = "dlsdk gstreamer1.0 gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
                  ttf-wqy-zenhei \
                 "

COMPATIBLE_MACHINE = "(dolphin)"

inherit pkgconfig systemd

SYSTEMD_SERVICE:${PN} = "dl-face.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} \
        ${WORKDIR}/dl_face.c \
        `pkg-config --cflags --libs gstreamer-1.0 gstreamer-app-1.0` \
        -ldlsdk -lusb-1.0 -lm \
        -o ${B}/dl_face
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${B}/dl_face ${D}${bindir}/dl_face

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/dl-face.service ${D}${systemd_system_unitdir}/dl-face.service
}

FILES:${PN} += "${systemd_system_unitdir}/dl-face.service"
