# Astra SL1680 Build Environment & Command Guide

**Date**: 2026-08-01　**Target**: Synaptics Astra SL1680 (Dolphin RDK)
**SDK version**: `scarthgap_6.12_v2.3.0` (Yocto 5.0 scarthgap / kernel 6.12.62)
**Audience**: colleagues setting up the same build environment. Every number in this document
was taken from the actual build machine in use — not copied from official docs.

---

## 0. The Big Picture

```
┌─ Windows 11 ────────────────────────────────────────────────┐
│  D:\...\sl1680-astra-terminal\   ← git repo (docs + our layers) │
│                                                              │
│  ┌─ WSL2: Ubuntu 22.04 ────────────────────────────────┐    │
│  │  /home/astra/sdk/            ← official SDK (pinned)  │    │
│  │    ├─ poky/                    Yocto 5.0.9            │    │
│  │    ├─ meta-synaptics/          official BSP layer     │    │
│  │    ├─ meta-openembedded/ etc.  ships with SDK         │    │
│  │    ├─ meta-dlsdk/        ★ OUR layer (linked in)      │    │
│  │    ├─ meta-tcm2-touch/   ★ OUR layer (touch driver)   │    │
│  │    └─ build-sl1680/            build directory        │    │
│  │         └─ tmp/deploy/images/sl1680/   artifacts      │    │
│  └──────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
                    │ scp / dd
                    ▼
            SL1680 board (192.168.5.126)
```

**Core principle: we do NOT fork the official SDK.** Upstream is pinned to a tag; every
modification of ours lives in two custom Yocto layers (kernel changes are applied as
`bbappend` + patch on top of the official `linux-syna` recipe). When upstream releases a
new version, we only swap the tag and re-validate.

---

## 1. Host Requirements (as measured)

| Item | This machine | Recommended minimum |
|---|---|---|
| OS | **Ubuntu 22.04.5 LTS** (WSL2) | Ubuntu 20.04/22.04, bare metal or WSL2 |
| CPU | 24 cores | ≥8 cores (more cores = faster full build) |
| RAM | 47 GB | ≥16 GB (linking chromium/qt is memory-hungry) |
| Disk | 1 TB (357 GB used; `tmp/` alone is **159 GB**) | **≥500 GB free**, SSD |
| Python | 3.10.12 | ≥3.8 |
| git | 2.34.1 | ≥2.28 |

> WSL2 users: keep the SDK on the **native WSL filesystem** (`/home/...`), never on
> `/mnt/c` — cross-filesystem IO slows the build by an order of magnitude. This machine
> mounts a dedicated 1 TB virtual disk (`/dev/sdd`) for WSL.

### 1.1 Package dependencies (standard Yocto scarthgap set + a few extras)

```bash
sudo apt update
sudo apt install -y gawk wget git diffstat unzip texinfo gcc build-essential \
  chrpath socat cpio python3 python3-pip python3-pexpect xz-utils debianutils \
  iputils-ping python3-git python3-jinja2 python3-subunit zstd liblz4-tool \
  file locales libacl1 bmap-tools
sudo locale-gen en_US.UTF-8
```

---

## 2. Getting the Source (four idempotent steps)

```bash
# 1) Official SDK — the version MUST be pinned; never build from master
git clone --branch scarthgap_6.12_v2.3.0 https://github.com/synaptics-astra/sdk ~/sdk
cd ~/sdk
# poky/meta-synaptics etc. ship inside the SDK; if they are submodules:
git submodule update --init --recursive 2>/dev/null || true

# 2) Our repository (contains meta-dlsdk / meta-tcm2-touch + all docs)
git clone git@github.com:hardyhuang818/sl1680-astra-terminal.git ~/sl1680-astra-terminal

# 3) Hook the layers in (idempotent script; symlinks the layer dirs + edits bblayers.conf)
~/sl1680-astra-terminal/tools/setup_sdk.sh ~/sdk

# 4) Verify the layers are registered
cd ~/sdk && source poky/oe-init-build-env build-sl1680
bitbake-layers show-layers | grep -E "dlsdk|tcm2"
```

### 2.1 Version anchors (for auditing)

| Component | Version |
|---|---|
| Astra SDK | tag `scarthgap_6.12_v2.3.0` |
| poky | yocto-5.0.9 (ships with SDK) |
| meta-synaptics | `d552818` (ships with SDK — do not upgrade independently) |
| kernel (linux-syna) | 6.12.62 |
| Our layers | `meta-dlsdk` (changelog in its `VERSION` file, currently v2.9) + `meta-tcm2-touch` |

### 2.2 Final shape of bblayers.conf (for cross-checking)

On top of the layers the SDK ships with, only two lines are appended at the end:

```
  /home/astra/sdk/meta-tcm2-touch \
  /home/astra/sdk/meta-dlsdk \
```

### 2.3 Key local.conf entries (SDK template defaults — listed for verification)

```
MACHINE ??= "sl1680"
PACKAGE_CLASSES ?= "package_deb"
INIT_MANAGER = "systemd"
LICENSE_FLAGS_ACCEPTED = "commercial Synaptics-EULA ..."
IMAGE_FSTYPES += " synaimg ext4 ext4.gz"
INITRAMFS_IMAGE_BUNDLE = "1"
```

The only switch we ever touch: `ASTRA_TERMINAL_PACKAGES = ""` (empty = skip our
voice/multi-display applications and fall back to the stock image).

---

## 3. Build Commands

**Every new terminal must enter the environment first** (bitbake only exists after sourcing):

```bash
cd ~/sdk && source poky/oe-init-build-env build-sl1680
```

### 3.1 Full image (first build: 3–6 hours depending on machine)

```bash
bitbake astra-media
```

Artifacts land in `tmp/deploy/images/sl1680/`:

| File | Purpose |
|---|---|
| `SYNAIMG/` | **Complete flashing bundle** (~2.5 GB) for the official USB flashing tool |
| `astra-media-sl1680.rootfs.ext4` | standalone rootfs image |
| `linux_bootimgs.subimg` | **boot bundle** (kernel + DTB + initramfs) — can be dd'ed alone |
| `Image-sl1680.bin` / `*.dtb` | raw kernel / device tree |

### 3.2 Fast kernel iteration (most-used daily loop, **~75 seconds** total)

After editing `dolphin-rdk.dts` or kernel sources:

```bash
bitbake linux-syna -C compile        # capital C: force re-run from compile (re-builds dts)
bitbake linux-syna -c deploy -f      # force re-deploy artifacts
```

> ⚠️ You are editing sources under `tmp/work-shared/sl1680/kernel-source/` —
> **this directory is volatile**; a `cleanall` wipes it. Every change must be captured
> back into a patch under `meta-dlsdk/recipes-kernel/linux/files/`
> (see §5.6 for the correct way to generate that patch).

After building, **verify the DTB at byte level** (a green build ≠ your change took effect):

```bash
python3 - <<'EOF'
b = open("/home/astra/sdk/build-sl1680/tmp/deploy/images/sl1680/dolphin-rdk.dtb","rb").read()
print("my node present:", b"synaptics,tcm-i2c" in b)
EOF
```

### 3.3 Single-package builds (after editing a recipe)

```bash
bitbake astra-voice                  # main voice application
bitbake sherpa-onnx                  # local ASR/TTS runtime
bitbake dl-face                      # DL7400 conversation UI
bitbake synaptics-tcm2               # touch driver kernel module (meta-tcm2-touch)
```

### 3.4 Cleaning (light to heavy)

```bash
bitbake <recipe> -c clean            # wipe work dir, keep sstate
bitbake <recipe> -c cleansstate      # also wipe sstate (forces a real rebuild)
bitbake <recipe> -c cleanall         # also wipe downloads (re-downloads everything! use sparingly)
```

> To verify "does my patch apply from scratch", `cleansstate` + rebuild is enough —
> do **not** reach for `cleanall` by default.

### 3.5 Debugging & inspection

```bash
bitbake <recipe> -e | grep ^SRC_URI=          # expanded value of any variable
bitbake <recipe> -c devshell                  # drop into the recipe's build shell
bitbake-layers show-recipes "*tcm*"           # which layer provides a recipe
bitbake-layers show-appends linux-syna        # who appends to it
oe-pkgdata-util find-path "*/astra_voice"     # which package owns a file
```

Build logs: `tmp/work/<arch>/<recipe>/<ver>/temp/log.do_<task>`

---

## 4. Flashing

### 4.1 Full flash (USB tool — first time / major versions)

On the Windows side use the official `usb-tool-astra-update` (board in USB flashing mode)
and feed it the whole `SYNAIMG/` directory. ~2.5 GB, under 10 minutes.

### 4.2 Boot-only flash (kernel/DTS iteration, 30 seconds)

dd directly while the board is running (both A/B slots) + **sha256 read-back verification**:

```bash
scp tmp/deploy/images/sl1680/linux_bootimgs.subimg root@192.168.5.126:/tmp/
ssh root@192.168.5.126 'sh -s' <<'EOF'
IMG=/tmp/linux_bootimgs.subimg
SZ=$(wc -c < $IMG)
dd if=$IMG of=/dev/mmcblk0p8 bs=1M 2>/dev/null
dd if=$IMG of=/dev/mmcblk0p9 bs=1M 2>/dev/null
sync
python3 -c "
import hashlib
exp = hashlib.sha256(open('$IMG','rb').read()).hexdigest()
for d in ('/dev/mmcblk0p8','/dev/mmcblk0p9'):
    got = hashlib.sha256(open(d,'rb').read($SZ)).hexdigest()
    print(d, 'OK' if got==exp else 'MISMATCH!')
"
EOF
```

Then **power-cycle the board** (see §5.1 — soft reboot is unreliable on this board).

### 4.3 Two things the image does NOT contain

| Missing | How to provide |
|---|---|
| ~2 GB of voice models (kept out of the image) | Copy to `/home/voice/` on the board after flashing; manifest in `meta-dlsdk/recipes-ai/astra-voice/files/README_models.md` |
| DLSDK binaries (DisplayLink NDA) | Place into `meta-dlsdk/recipes-graphics/dlsdk/files/` before building; file list + sha256 in `BINARIES_MANIFEST.txt` there. If you don't need DL7400, set `ASTRA_TERMINAL_PACKAGES = ""` in local.conf |

---

## 5. Pitfalls (every one of these actually bit us, sorted by pain)

### 5.1 Soft reboot is unreliable on this board
`reboot -f`, `systemctl reboot -ff`, sysrq — all ineffective. **Plan every boot-flash
around a manual power cycle**, and batch your changes into as few reboots as possible.

### 5.2 bbappend filename wildcard rules (the two traps are exact opposites)
- `linux-syna` recipe **is versioned** (6.12.62) → the append MUST be **`linux-syna_%.bbappend`** (with `_%`)
- `tzdata` recipe **is unversioned** → the append MUST be **`tzdata.bbappend`** (without `_%`)
Both mistakes produce the same message — `No recipes available for ...` — and bitbake
never tells you it's the filename.

### 5.3 cmake FetchContent is hard-disabled by Yocto (looks like a network failure)
`cmake.bbclass` sets `FETCHCONTENT_FULLY_DISCONNECTED=ON` by default. Third-party
downloads fail in do_configure with errors that look like connectivity problems — but no
network call ever happened. Fix: list every third-party tarball in `SRC_URI` (with sha256)
+ a `do_configure:prepend` that copies them into the source tree where
`possible_file_locations` expects them. Reference implementation (14 packages):
`meta-dlsdk/recipes-ai/sherpa-onnx/sherpa-onnx_1.13.4.bb`.

### 5.4 A .so without SOVERSION silently lands in the -dev package
The build is green, packages are produced — but the .so is missing on the board because
it was classified into `-dev`. The symptom appears very far from the cause. See the
`SOLIBS`/`FILES` handling in the sherpa-onnx recipe.

### 5.5 Four image-integration traps (a green build ≠ a working image)
① two packages shipping the same file → do_rootfs conflict; ② two services fighting over
one device (DLSDK is single-process exclusive); ③ package installed but service not
enabled (`SYSTEMD_AUTO_ENABLE` only works inside the recipe —
`SYSTEMD_AUTO_ENABLE:pn-X` in conf files does **not** work); ④ acceptance must read the
produced ext4 with debugfs — never trust the build manifest.

### 5.6 Never generate kernel patches with `git diff`
Yocto's `do_patch` commits the old patch into the kernel-source git HEAD, so `git diff`
only emits the **delta** (measured: 70 lines instead of the correct 248). Correct method:
run a full `diff -u` against the **pristine baseline** dts, then dry-run-replay to verify:

```bash
# baseline + patch == current source, byte-identical, or it doesn't count
patch -p1 --dry-run < new.patch && patch -p1 -s < new.patch && cmp patched-file current-file
```

### 5.7 debugfs does not follow symlinks
The real weston.ini is `/etc/xdg/weston/weston.ini.weston-init` (managed by
update-alternatives). When auditing an image with debugfs, inspect the real file, or you
will falsely report "config missing".

### 5.8 WSL specifics
- When invoking WSL from Windows for anything non-trivial, **write a script file** —
  inline commands get shredded by two layers of PowerShell/bash quoting
- Git Bash rewrites `/home/...` paths into Windows paths; invoke wsl from PowerShell

---

## 6. Board vs. Repository (team convention)

**The board is the source of truth.** Anything debugged directly on the board must be
flowed back into the repository and audited by sha256:

```bash
tools/export_live.sh        # pull board files and diff against the repo
```

- Version history: `meta-dlsdk/VERSION` (one entry per milestone, with board-side sha256)
- Per milestone: git commit + tag (v2.7, v2.8, v2.9…)
- Day-by-day changes: `backups/CHANGELOG.md`

## 7. Reference Documents

| Document | Content |
|---|---|
| `SETUP_SDK.md` | The minimal four-step reproduction recipe |
| `SL1680项目总览_2026-07-28.md` | Top-level project overview (EN version available) |
| `meta-dlsdk/VERSION` | Version history with per-release details |
| `SL1680_故障排查实录_2026-07-28.md` | Runtime troubleshooting log |
| `TD7800触摸根因与视觉唤醒修复_2026-07-28.md` | Full methodology of the voltage-domain root cause |

---

*Data taken from the actual build machine (Ubuntu 22.04.5 / 24 cores / 47 GB RAM /
tmp at 159 GB), verified 2026-08-01.*
*DLSDK binaries and panel vendor materials are under NDA — do not distribute with this document.*
