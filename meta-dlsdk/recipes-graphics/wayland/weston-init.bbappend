# TM10.5 面板物理倒装 -> DSI-1 输出 180° 旋转（触摸坐标 weston 自动跟转）
# 之前是烧完手工改 /etc/xdg/weston/weston.ini（rootfs 三件套之一），v2.8 起进镜像。
# 用追加而不是整文件替换：meta-synaptics 的 weston.ini（[screen-share] 等）原样保留。
do_install:append() {
    if [ -f ${D}${sysconfdir}/xdg/weston/weston.ini ]; then
        if ! grep -q "name=DSI-1" ${D}${sysconfdir}/xdg/weston/weston.ini; then
            cat >> ${D}${sysconfdir}/xdg/weston/weston.ini <<'EOF'

[output]
name=DSI-1
transform=rotate-180
EOF
        fi
    fi
}
