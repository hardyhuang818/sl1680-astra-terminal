SUMMARY = "DisplayLink SDK — userspace (libusb) driver for DL-3xxx..DL-7xxx"
DESCRIPTION = "Prebuilt aarch64 libdlsdk.so + headers + device firmware. \
Presents pixel buffers across multiple DisplayLink displays over USB. \
NO kernel module / evdi required — talks to the chip from userspace via libusb."
HOMEPAGE = "https://www.synaptics.com/products/displaylink-graphics"

# 闭源预编译二进制
LICENSE = "CLOSED"

SRC_URI = "file://libdlsdk.so \
           file://dlsdk.h \
           file://99-displaylink.rules \
           file://dlsdk-tmpfiles.conf \
           file://DL-firmware \
          "

S = "${WORKDIR}"

# 唯一的运行时外部依赖
DEPENDS = "libusb1"
RDEPENDS:${PN} = "libusb1"

# 只在 SL1680 (dolphin) 上构建
COMPATIBLE_MACHINE = "(dolphin)"

# 预编译二进制：关掉不适用的 QA 检查
INSANE_SKIP:${PN} += "already-stripped ldflags file-rdeps dev-so"
INSANE_SKIP:${PN}-dev += "dev-elf"
EXCLUDE_FROM_SHLIBS = "1"

# 二进制已经是 aarch64，不要试图重编/剥离
INHIBIT_PACKAGE_STRIP = "1"
INHIBIT_PACKAGE_DEBUG_SPLIT = "1"
INHIBIT_SYSROOT_STRIP = "1"

do_configure[noexec] = "1"
do_compile[noexec] = "1"

do_install() {
    # 共享库（SONAME 就是 libdlsdk.so，无版本号）
    install -d ${D}${libdir}
    install -m 0755 ${WORKDIR}/libdlsdk.so ${D}${libdir}/libdlsdk.so

    # 头文件
    install -d ${D}${includedir}/dlsdk
    install -m 0644 ${WORKDIR}/dlsdk.h ${D}${includedir}/dlsdk/dlsdk.h

    # 设备固件 spkg：SDK 初始化时按此目录自动保活/升级 DL7400 固件
    install -d ${D}${datadir}/displaylink/DL-firmware
    install -m 0644 ${WORKDIR}/DL-firmware/*.spkg ${D}${datadir}/displaylink/DL-firmware/

    # udev：让非 root 也能通过 libusb 打开 DisplayLink 设备 (VID 0x17e9)
    install -d ${D}${sysconfdir}/udev/rules.d
    install -m 0644 ${WORKDIR}/99-displaylink.rules ${D}${sysconfdir}/udev/rules.d/99-displaylink.rules

    # SDK 日志目录 (embedded mode 会写 /var/log/displaylink/dlsdk.log)
    # 注意：/var/log 在 Yocto 里是指向 /var/volatile/log 的符号链接，
    # 不能直接 install 进去(do_package 会报 "parent directory is a symlink")。
    # 正确做法是用 tmpfiles.d 让 systemd 开机时创建。
    install -d ${D}${nonarch_libdir}/tmpfiles.d
    install -m 0644 ${WORKDIR}/dlsdk-tmpfiles.conf ${D}${nonarch_libdir}/tmpfiles.d/dlsdk.conf
}

# .so 无版本号，属于运行时包而非 -dev
FILES:${PN} = "${libdir}/libdlsdk.so \
               ${datadir}/displaylink \
               ${sysconfdir}/udev/rules.d/99-displaylink.rules \
               ${nonarch_libdir}/tmpfiles.d/dlsdk.conf"
FILES:${PN}-dev = "${includedir}"
