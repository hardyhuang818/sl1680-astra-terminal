# meta-tcm2-touch

Yocto layer that integrates the Synaptics TouchComm v2 TDDI touchscreen driver
(`synaptics_tcm2_touchcomm_tddi_v1.8.0`) onto the **sl2619 / klamath** BSP.

Targets the TD7800 controller family, I2C bus, TouchComm v1 protocol.

## Layout

```
recipes-kernel/
  linux-drivers/synaptics-tcm2/
    synaptics-tcm2_1.8.0.bb         # out-of-tree module recipe
    files/synaptics_tcm2_...tar.gz  # driver source tarball
  linux/
    linux-syna_%.bbappend           # DT overlay drop-in + syna_drm mode tweak
    files/sl261x-tcm2-touch-overlay.dtso

recipes-core/
  images/astra-media.bbappend       # add module + evtest to image
```

## Enable

```bash
cd ~/sdk
MACHINE=sl2619 ACCEPT_SYNA_EULA=1 . meta-synaptics/setup/setup-environment
bitbake-layers add-layer ${TOPDIR}/../meta-tcm2-touch
bitbake astra-media
```

## Compat

- `LAYERSERIES_COMPAT_tcm2-touch = "scarthgap"` (Yocto 5.0.9 / kernel 6.12.62)
- `COMPATIBLE_MACHINE = "klamath"` on the module recipe (sl2619 sits in the
  klamath machine family)

See top-level `Astra-SDK-Build-Notes.md` §13 for the full integration write-up.
