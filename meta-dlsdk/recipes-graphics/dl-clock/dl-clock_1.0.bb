SUMMARY = "DL7400 时钟 + 跑马灯，开机自动运行"
DESCRIPTION = "在 DisplayLink 屏上显示当前时间(大字时钟)+日期+底部滚动跑马灯。\
这个场景正好发挥 DL3+ 按变化区域压缩的优势(只有数字和跑马条在变)，\
不像全屏视频那样只有 7fps。随 systemd 开机自启，DL7400 热插拔可自恢复。"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://dl_clock.c \
           file://dl-clock.service \
           file://dl-clock-reset.sh \
          "
S = "${WORKDIR}"

DEPENDS = "dlsdk libusb1 gstreamer1.0 gstreamer1.0-plugins-base"
# clockoverlay/textoverlay 在 -good(pango)，videotestsrc 在 -base
RDEPENDS:${PN} = "dlsdk gstreamer1.0 gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
                  liberation-fonts"

COMPATIBLE_MACHINE = "(dolphin)"

inherit pkgconfig systemd

SYSTEMD_SERVICE:${PN} = "dl-clock.service"

# ★★ 不能开机自启 ★★
#   DLSDK 是**单进程独占**的：一个进程握着 DL7400 时，第二个进程枚举到 0 个设备。
#   生产界面是 dl-face(表情脸+中英字幕)，它也默认自启。两个一起自启会互相抢设备，
#   表现为"屏幕黑着但 systemctl 显示 active"，非常难排查。
#   dl-clock 是演示程序，要看就手动跑：
#       systemctl stop dl-face && systemctl start dl-clock
#   ⚠️ 曾试过在 astra-media.bbappend 里写 SYSTEMD_AUTO_ENABLE:pn-dl-clock = "disable"，
#      **不生效** —— 这种 :pn- 覆盖只在 conf 文件(local.conf/layer.conf)里有效，
#      写在另一个 recipe 的 bbappend 里不管用。所以改在这里。
SYSTEMD_AUTO_ENABLE:${PN} = "disable"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} \
        ${WORKDIR}/dl_clock.c \
        `pkg-config --cflags --libs gstreamer-1.0 gstreamer-app-1.0` \
        -ldlsdk -lusb-1.0 -lm \
        -o ${B}/dl_clock
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${B}/dl_clock ${D}${bindir}/dl_clock
    install -m 0755 ${WORKDIR}/dl-clock-reset.sh ${D}${bindir}/dl-clock-reset.sh

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/dl-clock.service ${D}${systemd_system_unitdir}/dl-clock.service
}

FILES:${PN} += "${systemd_system_unitdir}/dl-clock.service"
