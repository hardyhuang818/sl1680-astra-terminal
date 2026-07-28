# Injects the TD7800 touch DT overlay into the kernel source tree so the
# existing SYNA_KERNEL_DTBO_FILE loop in linux-syna.inc compiles it, and
# nudges syna_drm's preferred HDMI mode to 720p for the HDMI→LVDS panel.
#
# Scope: only applies to klamath (sl2619 / sl26xx family).

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# --- klamath (sl2619): touch overlay only (HDMI display kept as-is) ---
SRC_URI:append:klamath = " file://sl261x-tcm2-touch-overlay.dtso"

do_configure:append:klamath() {
    install -m 0644 ${WORKDIR}/sl261x-tcm2-touch-overlay.dtso \
        ${S}/arch/arm64/boot/dts/synaptics/
}

SYNA_KERNEL_DTBO_FILE:append:klamath = " synaptics/sl261x-tcm2-touch-overlay.dtbo"

# --- dolphin (sl1680): touch overlay + MIPI-to-LVDS 1280x720 display overlay ---
SRC_URI:append:dolphin = " \
    file://dolphin-tcm2-touch-overlay.dtso \
    file://dolphin-td7800-lvds-overlay.dtso \
"

do_configure:append:dolphin() {
    install -m 0644 ${WORKDIR}/dolphin-tcm2-touch-overlay.dtso \
        ${S}/arch/arm64/boot/dts/synaptics/
    install -m 0644 ${WORKDIR}/dolphin-td7800-lvds-overlay.dtso \
        ${S}/arch/arm64/boot/dts/synaptics/
}

SYNA_KERNEL_DTBO_FILE:append:dolphin = " \
    synaptics/dolphin-tcm2-touch-overlay.dtbo \
    synaptics/dolphin-td7800-lvds-overlay.dtbo \
"

# Change syna_drm module option "hdmi_preferred_mode=1920x1080" -> 1280x720
# so the HDMI→LVDS breakout gets 720p first instead of 1080p→fallback.
do_install:append:klamath() {
    if [ -f ${D}${sysconfdir}/modprobe.d/syna_drm.conf ]; then
        sed -i 's/hdmi_preferred_mode=1920x1080/hdmi_preferred_mode=1280x720/' \
            ${D}${sysconfdir}/modprobe.d/syna_drm.conf
    fi
}
