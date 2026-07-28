# TM10.5-TD7800 10.5" 1280x720 LVDS 屏 (经 LAMTL/TC358775 DSI→LVDS 桥) + SM SPI2 调试通道
#
# 补丁内容 (对 dolphin-rdk.dts):
#   1. dsi_panel 节点: RPi 7寸配置 → TM10.5 时序 (1280x720@60, pclk 65.3MHz,
#      H 97/30/60, V 7/2/14), 删除指向不存在 RPi 电源芯片的 power-supply/backlight
#   2. command = TC358775 初始化序列 (29 条 DSI 通用长写):
#      单链第一链(OD口), VESA 24bit, LVCFG=0x41 (PCLKDIV=4)
#   3. Byte_clk=65300: DSI 261.2MHz 时钟线, 带宽余量 +33% —— 必须 > DSI 协议开销,
#      否则桥片行缓冲欠载 → 全屏雪花 (踩过的坑, 勿回调成 48975!)
#      公式: LVDS pclk = byteclk×4 ÷ PCLKDIV = 65.3MHz
#   4. &spi0 (SM SPI2) + spidev: TD7800 显示 SPI 调试通道 (J32.19/21/23/24)
#   5. spi2_data_pmux: 从 U-Boot 手里夺回 SM_SPI2_SDO/SDI (被复用成 uart2 流控)
#
# 板端硬件前提: 面板 U5.9 RESX 拉高 3.3V (悬空=整颗 TD7800 复位, 触摸+显示全哑);
#   LAMTL 1.8V 外供且 RST/PWR_EN 用 1.8V 电平 (3.3V 会经 RESX ESD 倒灌抬轨)。
# 详见 SL1680_td7800_boot/README_TD7800屏点亮.md
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI += "file://0001-dolphin-rdk-td7800-tm10p5-lvds-panel.patch"
