# TD7800 LVDS 调试代码备份

备份日期：2026-07-28　|　对应成果：TM10.5-TD7800 屏显示+触摸双链路点亮（详见上级目录 `TM10.5_TD7800屏点亮_总结_2026-07-28.md`）

**为什么要这份备份**：调试代码原本散在三处**易失位置**——① 会话 scratchpad（板侧脚本，会话结束即清）、② WSL work-shared 内核源码（`bitbake -c cleanall` 即清）、③ `tools/_wslout`（构建中转目录）。本目录把它们全部收拢为持久副本。

## 目录清单

### kernel-dts/ —— 核心成果（设备树）

| 文件 | 说明 |
|---|---|
| `dolphin-rdk.dts` | **最终版**内核设备树源码（含四块改动：TM10.5 dsi_panel + TC358775 command、触摸节点、SPI2+spidev、spi2 pinmux）。原路径：WSL `~/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/arch/arm64/boot/dts/synaptics/` |
| `dolphin-rdk.dts.pre_td7800` | 改动前的原始基线（两者 diff = 全部改动） |
| `dolphin-rdk-final.dtb` | 最终编译产物（44985 字节，与板端运行版本一致） |

### meta-dlsdk-patch/ —— 正式入库形态

| 文件 | 说明 |
|---|---|
| `linux-syna.bbappend` | Yocto 追加配方（注释里写明各改动缘由与"Byte_clk 勿回调"警告） |
| `0001-dolphin-rdk-td7800-tm10p5-lvds-panel.patch` | 186 行补丁（= 上面两个 dts 的 diff），正本在 `meta-dlsdk/recipes-kernel/linux/` |

### board-scripts/ —— 板侧调试脚本（43 个，busybox sh，经 tools/bsh.ps1 下发执行）

按调试阶段分组：

- **显示诊断**：`diag_lvds.sh`（第一轮全景：DRM/设备树/i2c/背光）、`diag_lvds2.sh`（overlay 机制探测）、`diag_lvds3.sh`（deferred/面板节点确认）、`diag_deep.sh` `diag_deep2.sh`（时钟树/扩展器寄存器直读/重发初始化）、`drm_state.sh`（DRM 管线状态）
- **烧录**：`flash2.sh` `flash3.sh` `flash_touch_and_banner.sh`（dd 双槽 + python 回读校验；`verify_flash.sh` 独立校验）、`reboot_persist_check.sh`（重启后 9 项自检）
- **SPI 控 TD7800**（含 9-bit DCX 帧的 ctypes/ioctl python 实现，板上 python3 无 fcntl 的绕法）：`gpio_probe.sh` `gpio_map.sh`（位敲候选与映射探测，后被硬 SPI 取代）、`check_pinmux.sh` `fix_mux_retest.sh`（发现并修复 U-Boot 占用 SDO/SDI）、`td_spi_test.sh`（位敲版）、`td_spidev_test2.sh`（**spidev 正式版：读 0xBF 器件码 + BIST**）、`spi_loopback.sh`（回环自证）、`full_retest.sh`（RESX 修复后全套重测）、`bist_off_lvds.sh`（关 BIST 切 LVDS 源）、`dispon_sleepout.sh`（29h/11h 点亮尾序）、`read_panel_cfg.sh`（**读面板 NVM：B1h LVDS 配置 / C0h 原生时序**）
- **触摸**：`int_probe1.sh` `int_probe2.sh`（**GPIO10 定位法：ATTN 锁低→I2C 排空→释放者即是**）、`touch_verify.sh`（驱动/中断/输入设备验证）、`evtest_win.sh` `evtest_win2.sh`（报点采样窗口）、`touch_cal.sh`（X 镜像校准 udev 规则）、`touch_demo.sh` `flip_and_demo.sh`（画板演示+180°翻转）、`weston_probe.sh`（weston 输入设备核查）
- **杂项**：`set_tz.sh`（时区）、`banner*.sh`（展示横幅：标题+走秒时钟，多行用多个 textoverlay）、`retrigger.sh`（重发桥片初始化）

### wsl-scripts/ —— WSL 侧构建与情报脚本（27 个）

- **dts 补丁器**（python，可重放）：`patch_dts_td7800.py`（屏节点替换）→ `patch_dts_spi.py`（SPI2+spidev）→ `patch_dts_margin.py`（**带宽余量修正：Byte_clk 65300 + LVCFG 0x41**）→ `patch_dts_touch.py`（触摸节点）——按此顺序对 `.pre_td7800` 重放可复现最终 dts
- **构建**：`build_boot_td7800.sh`（bitbake -C compile + deploy + DTB 字节级验证 + subimg 内嵌确认，75 秒）、`gen_patch.sh`（重新生成 186 行补丁）
- **情报挖掘**（datasheet/XLS/内核源码解析，复盘时有用）：`dig_overlay*.sh`（ws-panel command 机制发现）、`dig_drm_xls.sh` `dump_xls_*.sh` `find_bodies.sh` `dump_b1_c0.sh` `dump_restriction.sh` `lvcfg_body.sh` `grep_ds_volt.sh` `find_faildet.sh` `read_b1_dd.sh` `read_paneldsi.sh` `read_dts_drm.sh`（TC358775 XLS "Code"表解码、LVCFG/B1h/C0h 寄存器定义、面板 SPI 协议）、`spi2_recon*.sh` `find_gpio10.sh` `gpio_parents.sh` `find_smpinctrl.sh` `grep_levelshift.sh`（pinctrl/gpio 映射考古）

### evidence/ —— 症状留档

`f1.jpg` `f3.jpg`：零带宽余量时期的"活雪花"屏拍（视频抽帧）——第 5 层根因的典型症状，正本视频在 `TD7800/display abnormal.mp4`。

## 关联资产（不在本目录、已持久）

| 位置 | 内容 |
|---|---|
| `../SL1680_td7800_boot/` | 三代 boot 镜像 + 烧录/验证脚本 + 复盘 README |
| `../meta-dlsdk/recipes-kernel/linux/` | 补丁正本 + bbappend（VERSION v2.7 记账） |
| `../TD7800/` | TD7800B datasheet、厂商 initial code txt、异常视频 |
| `../MIPI to LVDS board-1/` | LAMTL 原理图/使用说明/TC358775 datasheet+timing XLS |
| 板端 `/home/boot_*_backup_td7800.img` | 点屏工程前的原始 boot（回退用） |
| 板端 rootfs 三件套 | weston.ini 翻转 / udev 触摸校准 / 时区（见总结文档 §4.4） |

## 完整性

`SHA256SUMS.txt` 覆盖本目录全部文件。验证：`sha256sum -c SHA256SUMS.txt`（WSL/Linux）。
