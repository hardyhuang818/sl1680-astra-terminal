# 把 DisplayLink SDK + demo/播放器/时钟 + 语音终端装进 SL1680 镜像。
#
# ⚠️ 这个 layer 只应该有【一个】astra-media.bbappend。
#    2026-07-24 曾一度出现两个(recipes-core/images 和 recipes-bsp/images)，
#    bitbake 会全部应用，很难看出谁加了什么。已合并到这里。

IMAGE_INSTALL:append:dolphin = " dlsdk dl-multiscreen-demo dl-player dl-clock libusb1 usbutils"

# 中文字体：镜像默认只有 Liberation(无 CJK 字形)，中文会渲染成"码点方框"乱码。
# 文泉驿正黑 ~14MB(装到 /usr/share/fonts/truetype/wqy-zenhei.ttc)，
# 程序按 fontconfig 家族名 "WenQuanYi Zen Hei" 引用，不写死路径。
IMAGE_INSTALL:append:dolphin = " ttf-wqy-zenhei"

# ═══ 语音终端 ═══
# 不想装：在 local.conf 里写 ASTRA_TERMINAL_PACKAGES = ""，不用删这个 bbappend。
ASTRA_TERMINAL_PACKAGES ?= "packagegroup-astra-terminal"
IMAGE_INSTALL:append:dolphin = " ${ASTRA_TERMINAL_PACKAGES}"

# dl-clock 不自启(会和 dl-face 抢 DL7400，DLSDK 单进程独占)。
# ⚠️ 这件事**不能**在这里做 —— SYSTEMD_AUTO_ENABLE:pn-dl-clock 这种 :pn- 覆盖
#    只在 conf 文件里有效，写在 image 的 bbappend 里不生效(实测)。
#    已改到 recipes-graphics/dl-clock/dl-clock_1.0.bb 里直接设 disable。

# 确保 deb 进 feed（与 meta-tcm2-touch 同样的坑：不加这句 do_rootfs 会找不到包）
do_rootfs[depends] += "dlsdk:do_package_write_deb \
                       dl-multiscreen-demo:do_package_write_deb \
                       dl-player:do_package_write_deb \
                       dl-clock:do_package_write_deb"
