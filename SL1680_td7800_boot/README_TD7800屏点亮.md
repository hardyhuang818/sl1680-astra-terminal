# TM10.5-TD7800 屏点亮 · boot 镜像烧录包

日期：2026-07-27　|　目标：SL1680 (dolphin RDK) 经 LAMTL (TC358775) 点亮 TM10.5-TD7800 1280×720 LVDS 屏

> **★ 2026-07-28 已点亮（Weston 桌面正常）。最终镜像 = `boot_td7800_margin.subimg`**
> （sha256 `9a86143dac2f0c7650a6ec8d9e113951898498229445ee5a21ba2528c78a8a9f`，已刷双槽）。
> 本文件下方记录的是首版镜像；完整五层根因与最终修复见文末"点亮复盘"。

## 点亮复盘（最终版，2026-07-28）

五层根因，按发现顺序：
1. **base dts 是树莓派屏配置**（800×480/1-lane/power-supply 指向不存在的 0x45 芯片）→ 替换为 TM10.5 时序节点
2. **TC358775 上电 LVDS 三态**，无人初始化 → 29 条 DSI 通用长写序列（29h 格式）烤进 DTB
3. **面板 U5.9 RESX 悬空** → 整颗 TD7800 复位（触摸 0x2C 消失+屏黑+SPI 无响应三症同源）→ 拉高 3.3V
4. **U-Boot 把 SM_SPI2_SDO/SDI 复用为 UART2 流控** → dts `spi2_data_pmux` 夺回（SPI 调试通道 /dev/spidev0.0）
5. **DSI→LVDS 零带宽余量 → 全屏活雪花**：DSI 包头/EoTp 开销使有效像素率 < 面板消耗率，桥片行缓冲每行欠载。
   修复：`Byte_clk 48975→65300`（+33% 带宽）+ `LVCFG 0x31→0x41`（PCLKDIV 3→4，LVDS 像素钟 = 261.2MHz÷4 = 65.3MHz 不变）。
   公式：**LVDS pclk = DSI 时钟线频率(byteclk×4) ÷ PCLKDIV；带宽余量必须显著大于 DSI 协议开销**（厂商例留 4.4%，我们留 33%）。

调试利器（保留在包内脚本+板上）：SPI 位敲/spidev 读写 TD7800——BIST（B0←00/D6←00/DE←01）、读器件码 BFh（=02 3C 68 0A）、读面板 NVM 配置（B1h/C0h）。面板侧接线：SPI J32.19/21/23/24 ↔ U5.1/2/4/3，RESX=U5.9 拉高，TP I2C J32.3/5，INT J32.12。

## 为什么屏点不亮（诊断结论）

1. **base 设备树的 `dsi_panel` 是树莓派 7 寸屏配置**（800×480、1-lane、TC358762 初始化命令），
   其 `power-supply` 指向 i2c0 0x45 的 RPi 面板电源芯片——物理不存在 → 面板驱动起不来 → DSI-1 一直 disconnected，SoC 根本不发 DSI 视频。
2. 就算面板节点活了，TC358775 上电后 LVDS 输出全三态，必须写寄存器初始化（LAMTL 板上无 MCU 代劳）。
3. `/boot` 里我们的 td7800 overlay 从未在开机时被应用（Astra 无 U-Boot overlay 自动应用机制，内核也没编运行时 overlay 支持）。

## 修复方式

直接替换 `dolphin-rdk.dts` 里的 `dsi_panel` 节点（烤进主 DTB，绕开 overlay 机制）：

- 时序：1280×720@60，pclk 65.3MHz，H 97/30/60，V 7/2/14（Case44 RK3568 实测值）
- Lanes 1→4，Byte_clk 84090→**48975**（DSI 位钟 391.8MHz ÷6 = 65.3MHz = LVDS 像素钟，与 LVCFG 分频严格自洽）
- 删除 power-supply/backlight 两个 RPi phandle（驱动对无属性走 ENODEV 容错，代码已核实）
- `command` 换成 **TC358775 初始化序列**（29 条 DSI 通用长写 + 2 个延时）：
  来源 = LAMTL 官方 XLS "Code" 表 + datasheet，HTIM/VTIM/VPCTRL 按我们时序重算；
  单链走第一链（=J3 的 OD/A 组）；色彩映射 = VESA 24bit（datasheet p39 原值）
- disp-mode 保持 2（HDMI + MIPI 双路），HDMI 不受影响

## 产物

| 文件 | 说明 |
|---|---|
| `boot_td7800.subimg` | 新 boot 镜像（签名 FIT，19110288 字节）|
| sha256 | `ca08fc5d9f2b96cab3727bc5f347c337ff8b795044b2ee38afdc33bd44262f9a` |
| `dolphin-rdk-td7800.dtb` | 新 DTB 单独留档（44134 字节）|
| `flash_boot_td7800.sh` | 板上烧录脚本（备份→刷 a/b 双槽→回读校验）|

已验证：新 DTB 含 TD7800 command / RPi 旧命令消失 / subimg 内嵌新 DTB（偏移 0x12319ad）。
已预置：两个文件已传到板上 `/tmp/`，板上 sha256 校验一致。

## 烧录步骤（板上）

```
sh /tmp/flash_boot_td7800.sh /tmp/boot_td7800.subimg ca08fc5d9f2b96cab3727bc5f347c337ff8b795044b2ee38afdc33bd44262f9a
reboot
```

脚本自动：备份 boot_a/boot_b 到 `/home/boot_*_backup_td7800.img` → 刷双槽 → 回读校验。

## 回退

```
dd if=/home/boot_a_backup_td7800.img of=/dev/mmcblk0p8 bs=1M
dd if=/home/boot_b_backup_td7800.img of=/dev/mmcblk0p9 bs=1M
sync; reboot
```

## 烧录前硬件必查（缺一屏必黑）

1. **1.8V**：LAMTL J1-8 (VCC1V8_LCM) 必须外部馈电——**板上 J208/J32 都没有 1.8V，LAMTL 也没有 1.8V 稳压器**（只有 1.2V LDO）。需 3.3V→1.8V 小 LDO。
2. **12V**：J1-1/2/3 (VCC12V_LCM) 外部 12V（背光），与板共地。
3. **3.3V**：J208-1 (PWR_3V3_CTL) → J1-6/7。
4. **使能**：J208-6 (PWR_ON_DSI) → J1-13 (LCM_PWR_EN)，可并 J1-12 (BL_EN)。
5. **复位（修正！）**：J1-14 (LCM_RST) **拉高到 3.3V**（不要接 expander——内核发 command 时必须已释放复位，没有软件会在那个时机去拉它）。
6. **DSI 数据**：J208 ↔ J1 五对差分按表（20/21→29/28、17/18→26/25、14/15→23/22、11/12→20/19、8/9→17/16，p 对 P、n 对 N）。
7. **LVDS**：LAMTL J3 OD 组（7~18 脚）→ 面板 U4 A 口（18~31 脚）按对接表；ED 组不接。
8. **J4 跳线**：面板 VCC 电压选择——TM10.5 供电从哪进还没查清，此项待定不影响点屏逻辑链路。

## 点亮后若有问题（按症状查）

| 症状 | 原因 | 处理 |
|---|---|---|
| 颜色灰暗/灰阶跳变 | VESA/JEIDA 映射反了 | 删 command 里 7 条 0x048x 写（回 JEIDA 默认），重建 |
| 图像水平/垂直滚动 | 同步极性 | H_polarity/V_Polarity 翻转重试 |
| 全黑但背光亮 | 桥片没收到初始化 | 查 RST 是否拉高、1.8V 是否在位、dmesg |
| DSI-1 仍 disconnected | connector 判定逻辑 | 跑 verify_after_boot.sh 收 dmesg 再分析 |

## 留痕

- dts 源码改动：WSL `kernel-source/.../dolphin-rdk.dts`（备份 `.pre_td7800`）
- ⚠️ 尚未回灌 meta-dlsdk 仓库（work-shared 是易失的，点亮验证后要做成 linux-syna 补丁入库）
