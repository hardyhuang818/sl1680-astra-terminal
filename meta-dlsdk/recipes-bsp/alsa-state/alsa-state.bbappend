# astra-voice 要装一份机器专用的 /etc/asound.conf（定义 pcm.astraout），
# 和 alsa-state 自带的同名文件撞车，rootfs 组装时 dpkg 直接失败：
#
#   trying to overwrite '/etc/asound.conf', which is also in package alsa-state
#
# alsa-state 那份**只有 32 字节、内容就一行注释** `# Global alsa-lib configuration`，
# 删掉不损失任何东西。这里删掉它，让 astra-voice 独占这个路径。
#
# 为什么不改用 /etc/alsa/conf.d/ 的 drop-in（alsa.conf 确实包含那个目录）：
# 板上现在跑的就是 /etc/asound.conf 这个布局，已验证可用；
# 改路径属于没法当场验证的改动，不值得为"更干净"冒险。以后要改再单独验。
#
# ⚠️ 只对 dolphin(SL1680) 生效，不影响其它机器。
# ⚠️ 若哪天不再由 astra-voice 提供 asound.conf，这个 bbappend 要一起删，
#    否则板子会完全没有 /etc/asound.conf。

do_install:append:dolphin() {
    rm -f ${D}${sysconfdir}/asound.conf
}
