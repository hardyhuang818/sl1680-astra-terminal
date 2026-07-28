# 固定公共 DNS —— 2026-07-28 踩坑：家庭路由(BE3600/代理)下发 Fake-IP DNS
# (198.18.0.0/15，RFC2544 保留段，不可路由)，板子解析云端 API 全部拿到假地址，
# 症状是"超时/查不到天气"，极易误判成 API key 失效或服务挂了。
# 排查口诀：板子换网络后先 nslookup，看到 198.18.x.x 就是这个坑。
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI += "file://99-astra-dns.conf"

do_install:append() {
    install -d ${D}${systemd_unitdir}/resolved.conf.d
    install -m 0644 ${WORKDIR}/99-astra-dns.conf \
        ${D}${systemd_unitdir}/resolved.conf.d/99-astra-dns.conf
}

FILES:${PN} += "${systemd_unitdir}/resolved.conf.d/99-astra-dns.conf"
