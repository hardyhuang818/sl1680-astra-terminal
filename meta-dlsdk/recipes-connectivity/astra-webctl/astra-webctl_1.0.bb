SUMMARY = "SL1680 Web 控制台(板端零依赖 API + 触屏前端) + TD7800 kiosk 浏览器服务"
DESCRIPTION = "python3 标准库 HTTP 服务(:8080)暴露白名单控制 API; \
cog/WPE 全屏跑在 DSI-1 (TD7800) 上把触摸屏变成本机控制台。\
kiosk 依赖 meta-webkit 层(scarthgap 分支)提供 cog/wpewebkit。"
LICENSE = "CLOSED"

SRC_URI = " \
    file://astra_webctl.py \
    file://webctl_index.html \
    file://wait_port.sh \
    file://pca9685.py \
    file://astra-webctl.service \
    file://astra-kiosk.service \
"

S = "${WORKDIR}"

inherit systemd

SYSTEMD_SERVICE:${PN} = "astra-webctl.service astra-kiosk.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

RDEPENDS:${PN} = "python3-core python3-json python3-netserver alsa-utils"
# kiosk 部分：cog 及其 WebKit 运行时(来自 meta-webkit 层)
RDEPENDS:${PN} += "cog wpewebkit libwpe wpebackend-fdo"

do_install() {
    install -d ${D}/home/voice/webctl
    install -m 0644 ${WORKDIR}/astra_webctl.py   ${D}/home/voice/webctl/astra_webctl.py
    install -m 0644 ${WORKDIR}/webctl_index.html ${D}/home/voice/webctl/index.html
    install -m 0755 ${WORKDIR}/wait_port.sh      ${D}/home/voice/webctl/wait_port.sh
    install -m 0755 ${WORKDIR}/pca9685.py        ${D}/home/voice/pca9685.py

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/astra-webctl.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/astra-kiosk.service  ${D}${systemd_system_unitdir}/
}

FILES:${PN} += "/home/voice"
