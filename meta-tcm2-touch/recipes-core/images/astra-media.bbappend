# Add TD7800 touch module + evtest debug tool to the astra-media rootfs.
# klamath = sl2619, dolphin = sl1680.

IMAGE_INSTALL:append:klamath = " kernel-module-synaptics-tcm2 evtest"
IMAGE_INSTALL:append:dolphin = " kernel-module-synaptics-tcm2 evtest"

# The kernel-module split creates a versioned package that RPROVIDES the bare
# name. bitbake's runtime-closure resolution doesn't reliably map that provide
# back to our out-of-tree recipe, so its .deb never gets hardlinked into the
# rootfs apt feed (do_rootfs then fails: "Unable to locate package ..."). Force
# the dependency so the .deb is staged into oe-rootfs-repo.
do_rootfs[depends] += "synaptics-tcm2:do_package_write_deb"
