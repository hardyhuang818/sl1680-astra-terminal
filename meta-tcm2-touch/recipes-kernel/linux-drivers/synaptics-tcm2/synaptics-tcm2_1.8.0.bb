SUMMARY = "Synaptics TouchComm v2 TDDI touchscreen driver (TD7800 family)"
DESCRIPTION = "Out-of-tree kernel module for Synaptics TCM2 TDDI touch controllers, \
including TD7800. Uses I2C interface with TouchComm v1 protocol."
LICENSE = "GPL-2.0-only"

# GPL-2 header in syna_tcm2.c lines 1-28 (md5 confirmed by first build).
LIC_FILES_CHKSUM = "file://syna_tcm2.c;beginline=1;endline=28;md5=ebcf73a8f5d542edf93b507968c4c0bb"

# sl2619 = klamath family, sl1680 = dolphin family
COMPATIBLE_MACHINE = "(klamath|dolphin)"

inherit module

SRC_URI = "file://synaptics_tcm2_touchcomm_tddi_v1.8.0.tar.gz \
           file://0001-enable-helper-and-fix-isr-deadlock.patch \
"

S = "${WORKDIR}/synaptics_tcm2_touchcomm_tddi_v1.8.0/source/synaptics_tcm2"

# The driver's Makefile uses ifeq($(CONFIG_...),y) to pick object files.
# We are out-of-tree, so set these as make vars, NOT via Kconfig.
EXTRA_OEMAKE += " \
    CONFIG_TOUCHSCREEN_SYNA_TCM2=m \
    CONFIG_TOUCHSCREEN_SYNA_TCM2_I2C=y \
    CONFIG_TOUCHSCREEN_SYNA_TCM2_TDDI=y \
    CONFIG_TOUCHSCREEN_SYNA_TCM2_TOUCHCOMM_VERSION_1=y \
    CONFIG_TOUCHSCREEN_SYNA_TCM2_SYSFS=y \
    CONFIG_TOUCHSCREEN_SYNA_TCM2_REFLASH=y \
"

# C sources also test with #ifdef CONFIG_... — pass as -D too.
# KCFLAGS is picked up by Kbuild ($(kbuild-file)/scripts/Makefile.build).
KCFLAGS += " \
    -DCONFIG_TOUCHSCREEN_SYNA_TCM2=1 \
    -DCONFIG_TOUCHSCREEN_SYNA_TCM2_I2C=1 \
    -DCONFIG_TOUCHSCREEN_SYNA_TCM2_TDDI=1 \
    -DCONFIG_TOUCHSCREEN_SYNA_TCM2_TOUCHCOMM_VERSION_1=1 \
    -DCONFIG_TOUCHSCREEN_SYNA_TCM2_SYSFS=1 \
    -DCONFIG_TOUCHSCREEN_SYNA_TCM2_REFLASH=1 \
"
export KCFLAGS

# Fallback include paths in case the driver Makefile's $(DIR) trick fails
# under out-of-tree layout. Kbuild honours ccflags-y from EXTRA_CFLAGS via env.
EXTRA_OEMAKE += " ccflags-y+=-I${S} ccflags-y+=-I${S}/tcm ccflags-y+=-I${S}/testing"

# Autoload the module at boot (handled by the stock module class packaging).
KERNEL_MODULE_AUTOLOAD:append:klamath = " synaptics_tcm2"
KERNEL_MODULE_AUTOLOAD:append:dolphin = " synaptics_tcm2"

# The kernel-module split creates a versioned package
# (kernel-module-synaptics-tcm2-6.12.62) that RPROVIDES the bare name. For
# `IMAGE_INSTALL += kernel-module-synaptics-tcm2` to resolve to THIS recipe at
# parse/dependency time (so its .deb gets staged into the rootfs feed),
# PACKAGES_DYNAMIC must match the kernel-module namespace. Without this the
# image builds, PACKAGE_INSTALL lists the module, but apt can't find its .deb.
PACKAGES_DYNAMIC += "^kernel-module-.*"

do_configure:append() {
    # (1) Kernel 6.12 fix: Linux 6.11 changed platform_driver.remove from
    #     `int (*)(...)` to `void (*)(...)`. syna_dev_remove() returns int,
    #     tripping -Werror=incompatible-pointer-types. Retarget just that
    #     function (signature + its two `return 0;`) to void.
    sed -i \
      -e '/^static int syna_dev_remove(struct platform_device \*pdev)$/,/^}$/{
              s/^static int syna_dev_remove(struct platform_device \*pdev)$/static void syna_dev_remove(struct platform_device *pdev)/
              s/^\(\t*\)return 0;$/\1return;/
          }' \
      ${S}/syna_tcm2.c

    # (2) The driver ships ONLY a Kbuild fragment (obj-$(CONFIG_...) += ...)
    #     with no top-level target — meant for in-tree builds. The stock
    #     module.bbclass runs `make [modules_install]` and needs those targets.
    #     Rename the fragment to Kbuild and drop in a thin wrapper Makefile so
    #     the class handles compile / install / kernel-module split correctly
    #     (same flow as the working synasdk-drivers-isp recipe).
    if [ -f ${S}/Makefile ] && [ ! -f ${S}/Kbuild ]; then
        mv ${S}/Makefile ${S}/Kbuild
        cat > ${S}/Makefile <<'MKEOF'
KERNEL_SRC ?= /lib/modules/$(shell uname -r)/build
KDIR ?= $(KERNEL_SRC)
all modules:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules
modules_install:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules_install
clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
.PHONY: all modules modules_install clean
MKEOF
    fi
}
