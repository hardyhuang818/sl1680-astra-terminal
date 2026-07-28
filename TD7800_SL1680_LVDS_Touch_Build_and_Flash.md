# TD7800-TM 10.5" LVDS 屏 + 触摸 @ SL1680 —— Build & 烧录指南

> **平台**: Synaptics SL1680 (dolphin family) · Astra SDK `scarthgap_6.12_v2.3.0` · kernel 6.12.62
> **屏**: TD7800-TM 10.5" 1280(RGB)×720，**MIPI-DSI → MIPI转LVDS 转接板 → LVDS panel**
> **触摸**: TD7800 TDDI，Synaptics TouchComm TCM2 v1.8.0，I²C @ **0x2C**，走 i2c0
> **原理图**: `Case6_Astra/SL1680/SC950-000798-01 RevE-L16X0 RDK IO SCHEMATIC BOARD.pdf`
> **状态**: ✅ **build 成功，`SYNAIMG/` 已产出（2.4 GB，含触摸驱动 + 2 个 DT overlay）** · 显示/触摸接线待实机确认（见 §6 TODO）
> **构建完成**: 2026-07-13 · 8 个坑全部解决（见 [§8.1/§8.2 踩坑](#81--wsl2-致命坑pseudo-拦不住-openat2--所有-do_packagedo_rootfs-失败)）

与 RK3568 案（`TD7800_RK3568_LVDS_Touch_Case_Summary.md`，同屏、已实测通过）的关系：
**触摸驱动 + 全部 TDDI 经验直接复用；显示侧因平台不同（SL1680 走 MIPI-DSI 而非 RK 原生 LVDS）需重做。**

---

## 1. 与 RK3568 案的差异对照

| 维度 | RK3568（已通过） | SL1680（本案） |
|---|---|---|
| SoC 显示输出 | 原生 LVDS（VP2） | **MIPI-DSI**（4-lane）→ 外部转接板 → LVDS |
| 内核 | 4.19 (Android12) | **6.12.62** (Yocto/Linux) |
| 触摸驱动构建 | 内建 `=y` | **out-of-tree module `.ko`** |
| 触摸 EPROBE_DEFER 时序坑 | 需修（内建时 i2c 晚于驱动） | **不需要**（模块加载时 i2c 已就绪） |
| `drm_bridge_connector.h` 版本坑 | 需守卫（4.19 无此头） | **不需要**（6.12 ≥ 5.5 有此头） |
| TDDI TP_RESET 常拉高 | gpio-hog | **同样需要**（见 §5） |
| 触摸 I²C 地址 | 0x2C @ i2c3 | 0x2C @ **i2c0**（DSI 面板连接器总线） |
| 方向宏 FLIP/SWAP | 编译期宏 | 同机制（首点亮后按需调） |

> 结论：RK3568 案里那些**内核版本相关**的补丁（EPROBE_DEFER、drm_bridge_connector 守卫）在 SL1680 的 6.12 模块构建下**不需要**。TDDI 复位经验仍适用。

---

## 2. SL1680 显示架构（关键背景）

`dolphin-rdk.dts` 的 `&drm` 用 Synaptics 自定义 `dsi_panel` 节点描述 DSI 输出（不是 mainline panel-simple）：

```
[SoC MIPI-DSI 4-lane] → [MIPI转LVDS 转接板] → [TD7800 LVDS panel 1280x720]
       ↑ dsi_panel 节点给出时序        ↑ 桥接芯片转换       ↑ 面板
```

对**自动配置型**转接板（从 DSI 视频流推导 LVDS 时序），SoC 侧只要按面板原生时序发 DSI 流即可，转板自动转换。这正是本方案采用的路线。

RDK 板上 DSI 连接器（原理图 page 7 "07: CONN - MIPI DSI"）提供：
- 4-lane MIPI DSI（TD0-3 + TCK）
- `PWR_ON_DSI`（高有效，来自 `expander0` bit1）—— 面板/转接板供电使能
- `GPIO_DSI`（来自 `expander0` bit7）—— 备用控制/复位
- I²C（`V1P8.SoC.SDA/SCL` 经电平转换到 3V3）—— 触摸 + 面板 EEPROM

`panel0-backlight` 节点已用 `enable-gpio=<&expander0 1>`（即 PWR_ON_DSI）+ PWM0 ch1 驱动背光/供电。

---

## 3. 1280×720 时序（来自 RK3568 案实测）

| 参数 | 值 | dsi_panel 字段 |
|---|---|---|
| 像素时钟 | 65.3 MHz | FREQ / PIXEL_CLOCK = 65300 |
| H active | 1280 | ACTIVE_WIDTH |
| H front porch | 97 | HFP |
| H sync width | 30 | HSYNCWIDTH |
| H back porch | 60 | HBP |
| V active | 720 | ACTIVE_HEIGHT |
| V front porch | 7 | VFP |
| V sync width | 2 | VSYNCWIDTH |
| V back porch | 14 | VBP |
| H total | 1467 | HTOTAL |
| Lanes | 4 | Lanes |
| Byte_clk | 48975 kHz | = 65300×24/(4×8) |

自检：1467 × 743 × 60Hz ≈ 65.4 MHz ≈ 65.3 MHz ✓

---

## 4. 交付物：`meta-tcm2-touch` layer

不改上游 `meta-synaptics`，所有定制在独立 layer `~/sdk/meta-tcm2-touch/`（同时覆盖 sl2619/klamath 与 sl1680/dolphin）：

```
meta-tcm2-touch/
├── conf/layer.conf                         # BBFILES 匹配 3+4 层深度
├── recipes-kernel/
│   ├── linux-drivers/synaptics-tcm2/
│   │   ├── synaptics-tcm2_1.8.0.bb         # out-of-tree module recipe
│   │   └── files/synaptics_tcm2_..._v1.8.0.tar.gz
│   └── linux/
│       ├── linux-syna_%.bbappend           # 注入 overlay + (klamath) HDMI 720p
│       └── files/
│           ├── sl261x-tcm2-touch-overlay.dtso        # sl2619 触摸
│           ├── dolphin-tcm2-touch-overlay.dtso       # sl1680 触摸 ★
│           └── dolphin-td7800-lvds-overlay.dtso      # sl1680 MIPI-LVDS 显示 ★
└── recipes-core/images/astra-media.bbappend # IMAGE_INSTALL += 模块 + evtest
```

**module recipe** 要点：
- `inherit module`，源码来自 tarball（`file://...tar.gz`）
- 驱动 Makefile 用 `ifeq($(CONFIG_...))` 选组件 → recipe 里用 `EXTRA_OEMAKE` + `KCFLAGS -D` 双管齐下开：`TCM2 / I2C / TDDI / TOUCHCOMM_VERSION_1 / SYSFS / REFLASH`
- `COMPATIBLE_MACHINE = "(klamath|dolphin)"`
- `KERNEL_MODULE_AUTOLOAD` 开机自动加载

**dolphin 触摸 overlay**（i2c0 @ 0x2C）：应用 TDDI 经验——**无 `synaptics,reset-gpio`**（TP_RESET 归外部常拉高，见 §5）。

**dolphin 显示 overlay**：把 `dsi_panel` 覆写成 §3 的 1280×720 时序，`disp-mode=1`(MIPI only)，禁用 LT9611 HDMI bridge。

---

## 5. ★ 关键：TDDI 的 TP_RESET（沿用 RK3568 教训）

TD7800 是 **TDDI（触摸+显示同一颗芯片）**。`TP_RESET` 复位整颗芯片**含显示驱动 IC** → 若触摸驱动持有 TP_RESET（active-low），显示初始化时被拉低 → **屏黑**。

**规则**：TP_RESET 必须上电即拉高并保持。做法二选一：
1. 硬件上拉到 3.3V（转接板/面板 FPC 若已上拉，最省事）
2. DTS `gpio-hog` 让对应 GPIO 上电常驱动高（参考 RK3568 案 `&gpio3 td7800_tp_reset_hog`）

因此触摸节点**不给** `reset-gpio`；复位后恢复交给驱动内 `ENABLE_HELPER`（v1.8 默认已开 LOW_POWER_MODE，组合可用）。

> SL1680 上 TP_RESET 究竟接哪根线取决于转接板+面板 FPC 接线（第三方板，不在 RDK 原理图内）——需实测确认，必要时加 gpio-hog。

---

## 6. TODO（实机 bring-up 前必须确认）

| 项 | 现状 | 待确认 |
|---|---|---|
| MIPI转LVDS 转接板芯片型号 | 未知 | 决定是否需 I²C/DCS 初始化（见 §7 决策树） |
| 触摸 INT GPIO | overlay 占位 `<&portc 0>` | 换成实际接到面板 FPC 的 SoC GPIO |
| TP_RESET 接线 | 假设外部常高 | 实测；否则加 gpio-hog |
| DSI lane 数 | 模板用 4 | 按转接板确认（2 或 4） |
| LVDS data mapping | 假设 VESA/SPWG 24bit | 偏色则调转接板 strap 或面板 JEIDA/SPWG |
| 触摸 0x2C | RK3568 实测 0x2C | 确认转接板未改地址 |

---

## 7. 转接板类型决策树（显示能否亮的关键）

```
转接板芯片是哪种？
├─ 自动配置型（从 DSI 流推导 LVDS，无需寄存器配置）
│    例：部分 ICN6202/6211 模式、某些"哑"转板
│    → 本方案模板即可，dsi_panel 时序对了就亮
│
├─ 需 I²C 配置（SN65DSI84/85, LT8912, TC358775 ...）
│    → 需要 ①kernel bridge driver + ②DT 里桥接芯片 I²C 节点
│    → 或在 dsi_panel 加 DCS 初始化命令序列（command = /bits/8 <...>）
│
└─ 需 DCS 初始化（面板/桥集成）
     → 在 dsi_panel 的 command 字段填初始化序列（参考 dolphin-haier-panel-overlay.dtso）
```

拿到转接板型号后回来更新 `dolphin-td7800-lvds-overlay.dtso`。

---

## 8. Build

```bash
# 进 WSL
wsl -d Ubuntu-22.04
cd ~/sdk

# 配置 sl1680 + 加 layer + build（脚本已封装，复用 sl2619 sstate 加速）
bash "/mnt/d/Claude code/Case44_RK3568/build-sl1680.sh"
```

脚本 `build-sl1680.sh` 做的事：
1. `MACHINE=sl1680 ACCEPT_SYNA_EULA=1 . meta-synaptics/setup/setup-environment`
2. `conf/local.conf` 追加 `DL_DIR`/`SSTATE_DIR` 指向 sl2619 缓存（复用，省时）+ `BB_SRCREV_POLICY="cache"`
3. `bitbake-layers add-layer /home/astra/sdk/meta-tcm2-touch`（绝对路径，注意 `${TOPDIR}` 是 bitbake 变量不能在 shell 用）
4. **WSL2 pseudo/openat2 workaround**（见 §8.1）
5. `bitbake --continue astra-media`，5 次 fetch 重试（应对 tim-vx/optee-os 等 git clone 瞬断）

**产物**：`~/sdk/build-sl1680/tmp/deploy/images/sl1680/SYNAIMG/`

### 8.1 ★ WSL2 致命坑：pseudo 拦不住 openat2 → 所有 do_package/do_rootfs 失败

**现象**：`do_package` / `do_rootfs` 报
```
got *at() syscall for unknown directory, fd 4
unknown base path for fd 4, path modules
couldn't allocate absolute path for 'modules'.
tar: ./lib/modules: Cannot mkdir: Bad address
```

**根因**（strace 铁证）：
- Yocto 的 `pseudo`（fakeroot）靠 **LD_PRELOAD** 拦截文件系统调用来伪造 root 权限记账。
- **GNU tar 1.34** 进入子目录用的是 **`openat2()` 裸系统调用**（带 `RESOLVE_BENEATH` 安全解析），而 poky 的 pseudo **没有 wrap `openat2`**（LD_PRELOAD 本就拦不住裸 syscall）。
- 于是 pseudo 丢失 tar 打开的目录 fd → `mkdirat(fd,...)` 记账失败 → `Bad address`。
- WSL2 kernel 6.6 支持 openat2，Ubuntu 22.04 的 tar 用它 → **每个 do_package/do_rootfs 都挂**。（普通原生 Linux 也可能中招，取决于 tar/kernel 版本。）

**修法**：用 seccomp 强制 `openat2` 返回 `ENOSYS`，让 GNU tar 回退到 `openat()`（pseudo 能 wrap）。
- `no_openat2.c`：一个装 seccomp BPF 过滤器（openat2→ENOSYS）后 exec 目标命令的小程序。
- `~/toolwrap/{tar,cp,rsync,...}`：把这些工具包一层，全走 `no_openat2`。
- 在 bitbake 前把 `~/toolwrap` 加到 PATH 最前 → bitbake 的 HOSTTOOLS 把 `tar` 等符号链接指向 wrapper。
- 全部封装在 `build-sl1680.sh` 里，幂等。

> 验证：`pseudo bash -c 'tar -cf - -C src . | no_openat2 tar -xf - -C dst'` 成功；`bitbake -f -c package zlib` 成功。

### 8.2 完整踩坑清单（8 个，按发现顺序，全部已解决）

从 0 到产出 `SYNAIMG/` 一共踩了 8 个坑。前 3 个是模块编译/打包，中间 2 个是环境，后 3 个是网络与 Yocto 打包依赖解析。

| # | 现象 | 根因 | 修法 |
|---|---|---|---|
| 1 | `do_package`/`do_rootfs` 全挂：`unknown base path for fd N` / `mkdir: Bad address` | **pseudo(fakeroot)靠 LD_PRELOAD,拦不住 GNU tar 1.34 的 `openat2()` 裸系统调用**(WSL2 kernel 6.6 支持 openat2)→ 目录 fd 追踪失效 | seccomp launcher 强制 `openat2→ENOSYS`,tar 回退到 `openat()`;wrapper 走 HOSTTOOLS PATH（§8.1） |
| 2 | `syna_tcm2.c:2139 .remove incompatible pointer type` | kernel 6.11+ 把 `platform_driver.remove` 从返回 `int` 改成 `void`;驱动是 2024 v1.8 没跟上 | recipe `do_configure:append` sed 把 `syna_dev_remove` 改成返回 void |
| 3 | `make: *** No targets. Stop.` | 驱动 Makefile 是纯 Kbuild 片段(无 `all:`/`modules:` 顶层目标),为 in-tree 设计 | `do_configure:append` 把 Makefile 改名 `Kbuild` + 写 wrapper Makefile,让标准 module 类接管(compile/install/split) |
| 4 | `LIC_FILES_CHKSUM does not match` | md5 占位 | 首次 build 报正确 md5(`ebcf73a...`)回填 |
| 5 | bitbake 连到旧 daemon,忽略新 PATH(wrapper 不生效) | **bitbake-server(cooker daemon)常驻,缓存旧环境** | 脚本先 `pkill -9 -f bitbake-server` 再跑 |
| 6 | 大 git clone(ta_enc/preboot)反复 `GnuTLS recv error / early EOF` | **WSL2 网络 MTU 问题**:大传输在 TLS 层被掐断 | `ip link set eth0 mtu 1280` + git `http.version HTTP/1.1` + **浅克隆**(`--depth 1 --branch`,SRCREV 恰好=分支 tip)放到 git2 mirror 路径 |
| 7 | `do_rootfs`: `E: Unable to locate package kernel-module-synaptics-tcm2` | **① `PACKAGES_DYNAMIC` 缺 `^kernel-module-.*`;② 模块 deb 没被硬链接进 rootfs apt feed**(deploy/deb 有,feed 没有) | recipe 加 `PACKAGES_DYNAMIC += "^kernel-module-.*"` + bbappend 加 `do_rootfs[depends] += "synaptics-tcm2:do_package_write_deb"` |
| 8 | `torq-*.bb parse ExpansionError`(`ls-remote` TLS 断) | torq recipe 在 **parse 期**对 `torq-compiler.git` 做 AUTOREV `ls-remote`,偶发网络失败 | `BB_SRCREV_POLICY="cache"` + MTU 1280 + **parse 重试**(bitbake 重跑几次) |

> **两个最隐蔽的坑**：#1（pseudo/openat2，用 strace 才定位）和 #7（feed 依赖解析，deb 明明构建了却进不了镜像）。

### 8.3 最终产物（2026-07-13 构建成功）

`~/sdk/build-sl1680/tmp/deploy/images/sl1680/SYNAIMG/`（共 **2.4 GB**）

| 文件 | 大小 | 说明 |
|---|---|---|
| `preboot.subimg.gz` | 451K | Preboot |
| `bl.subimg.gz` | 383K | Bootloader |
| `boot.subimg.gz` | 16M | Boot 分区（kernel + dtb + **dtbo overlay**） |
| `tzk.subimg.gz` | 1.4M | TrustZone kernel（含 optee ta_enc） |
| `rootfs.subimg.gz` | 737M | 主 rootfs（**含 `synaptics_tcm2.ko` + evtest**） |
| `rootfs_s.subimg.0-5` | ~1.6G | 分片 rootfs |
| `home.subimg.gz` | 20M | /home |
| `fastlogo.subimg.gz` | 938K | 开机 logo |
| `emmc_image_list` / `emmc_part_list` | — | 烧录顺序 + GPT 分区表 |

**镜像里已集成**：
- `synaptics_tcm2.ko`（`kernel-module-synaptics-tcm2` 包，开机 `modprobe synaptics_tcm2` 自动加载）
- `dolphin-tcm2-touch-overlay.dtbo`（触摸 @ i2c0 0x2C）
- `dolphin-td7800-lvds-overlay.dtbo`（MIPI→LVDS 1280×720）
- `evtest`（触摸调试）

---

## 9. 烧录 eMMC（SL1680 Astra Machina）

产物是 `SYNAIMG/`（= 烧录工具里说的 `eMMCimg` 目录），含 `*.subimg.gz` + `emmc_image_list`（镜像→分区顺序）+ `emmc_part_list`（GPT，A/B 双分区）。以下 3 种方式来自 Synaptics 内部 Confluence（BDT / WCD 空间），已核实。

> **关键 jumper/按键**：
> - `SD_BOOT` jumper：**接上** = 从 U-Boot / SD 启动（方式二/三用）；**断开** = 正常从 eMMC 启动（方式一用）。
> - `USB_BOOT` 按钮 + `RESET` 按钮：方式一进 USB Boot 模式用。
> - UART：115200 8N1，TX↔RX 交叉，共 GND。登录 `root`，无密码。

### 9.1 方式一：USB Boot 烧录（★推荐，PC 主机直连）

1. 工具：从 https://github.com/synaptics-astra/usb-tool 下载（含 `astra-update`）。
2. **Windows 装 WinUSB 驱动**：右键 `SYNA_WinUSB.inf` → 安装。
3. USB 线接 PC ↔ SL1680 的 **USB Type-C USB 2.0 口**（靠近网口那个）。
4. 把本案产物 `SYNAIMG/`（或改名 `eMMCimg`）整个目录放进 `usb-tool` 目录。
5. 运行 `update_emmc` 脚本（Linux/Windows 各有对应入口，内部调用 `astra-update`）。
6. **进 USB Boot 模式**：按住板上 `USB_BOOT` 按钮，同时按一下 `RESET` 再松开。
7. 工具自动烧录到 eMMC，完成后板子自动重启。
8. ⚠️ 确认 `SD_BOOT` jumper **未接**，否则会从 SPI/SD 启动。

> 产物目录准备：
> ```bash
> # 从 WSL 拷出到 Windows，喂给 usb-tool
> cp -r ~/sdk/build-sl1680/tmp/deploy/images/sl1680/SYNAIMG \
>       "/mnt/d/Claude code/Case44_RK3568/out_images_sl1680/eMMCimg"
> ```

### 9.2 方式二：USB U 盘烧录（U-Boot `usb2emmc`）

1. **FAT32** 格式 U 盘，把 `SYNAIMG/`（即 `eMMCimg`）目录拷进去。
2. U 盘插入 SL1680 USB 口；接 UART（115200）。
3. **接上 `SD_BOOT` jumper**，上电进入 U-Boot。
4. U-Boot 下执行：
   ```
   => usb2emmc eMMCimg
   ```
5. 完成后**移除 `SD_BOOT` jumper**，`reset` 重启。

### 9.3 方式三：TFTP 网络烧录（U-Boot `tftp2emmc`）

1. PC 网线直连 SL1680，PC IP 设 `10.10.10.2`，开 TFTP 服务器（如 tftpd64），image 目录设为 Current Directory。
2. **接上 `SD_BOOT` jumper**，上电进入 U-Boot。
3. U-Boot 下执行：
   ```
   => setenv ipaddr 10.10.10.10
   => tftp2emmc 10.10.10.2:eMMCimg
   ```
4. 完成后移除 `SD_BOOT` jumper，`reset` 重启。

### 9.4 方式对比

| 方式 | host 侧 | 需 UART | 需 jumper | 适用 |
|---|---|---|---|---|
| 一 USB Boot | usb-tool + WinUSB | 否 | SD_BOOT 断开 | 日常首选，最省事 |
| 二 U 盘 | 只需 FAT32 U 盘 | 是 | SD_BOOT 接上 | 无专用工具/现场 |
| 三 TFTP | TFTP server + 网线 | 是 | SD_BOOT 接上 | 批量/远程 |

> 参考 image 命名：官方最新预编译为 `SYNAIMG_v2.4.0_20260629_sdio.zip`（scarthgap_6.12_v2.4.0）。本案自编译为 v2.3.0，烧录方法完全一致；`SYNAIMG/` 目录即 `eMMCimg`。

---

## 10. 上板验证清单

启动后（串口 `serial0:115200n8`）：

```bash
# 触摸模块加载
lsmod | grep synaptics_tcm2
dmesg | grep -iE 'synaptics|tcm2|td7800|touch'
# 期望：Device in Application FW, td7800-... / synaptics_tcm ver.: 1.8.0, installed

# input 设备
cat /proc/bus/input/devices | grep -iA3 synaptics
evtest /dev/input/eventN     # 手指点屏看报点

# 显示分辨率
cat /sys/class/drm/card0-DSI-1/modes 2>/dev/null | head
# 期望 1280x720
```

若屏黑：先查 TP_RESET 是否上电即高（§5）；若花屏/偏色：查转接板 lane 数 / LVDS mapping（§6）。

---

## 11. 文件清单

| 文件 | 说明 |
|---|---|
| `Case44_RK3568/build-sl1680.sh` | 一键 build（env + layer + 重试 bitbake） |
| `Case44_RK3568/TD7800_RK3568_LVDS_Touch_Case_Summary.md` | RK3568 姊妹案（触摸经验来源） |
| `~/sdk/meta-tcm2-touch/` | 触摸 + 显示定制 layer |
| `~/sdk/build-sl1680/tmp/deploy/images/sl1680/SYNAIMG/` | 烧录产物 |
| `Case6_Astra/SL1680/SC950-000798-01 RevE-...pdf` | SL1680 RDK 原理图 |
| `Case6_Astra/Astra-SDK-Build-Notes.md` | Astra SDK 通用 build 手册 |

---

*— SL1680 TD7800 LVDS+触摸集成 · 基于 RK3568 姊妹案复用 —*
