#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""移除 TD7800 两个复位脚的 gpio-hog —— SoC 1.8V pad 驱不动 3.3V 域的复位输入

实测定性（2026-07-28）：
  J32.32 TP_RST (TCH_RESET_N) = 1.57V
  J32.33 LCD_RESET (RESET_N)  = 2.28V
TD7800B datasheet：RESET_N / TCH_RESET_N 属 IOVCC 域（Table 44 第6项），
IOVCC = 2.7~3.6V（Table 50），VIH1 = 0.70 × IOVCC → 3.3V 时最低 2.31V（Table 51）。
1.57V 和 2.28V 都落在 VIL(0.99V) 与 VIH(2.31V) 之间的禁区 —— 芯片看到的既不是高也不是低，
触摸引擎不启动、ATTN 永不拉低，而 I2C 从机块照样应答，于是"半死"。
2.28V = 1.8V + 0.48V 正好是 pad 上端 ESD 二极管压降，说明面板侧 3.3V 上拉在倒灌。

拔掉两根杜邦线后立刻验证成立：中断从 0 跳到 2626，dmesg 出现两次
`syna_dev_process_unexpected_reset`（拔线产生的复位脉冲，被打了补丁的自愈驱动接住）。

**1.8V GPIO 永远给不出 2.31V，这不是软件能修的。**
现状：两根线已物理拔除，面板自带 3.3V 上拉把两个复位脚拉到干净的高电平。
本补丁把 hog 删掉，避免 SoC 继续对着 3.3V 上拉硬顶。

⚠ 要恢复 SoC 控制复位，必须先加 1.8V→3.3V 电平转换（推荐固定方向的 74LVC2T45，
  VCCA=1.8V/VCCB=3.3V；或每线一颗 2N7002 + 10k 上拉到 3.3V。
  不要用 TXB0102/TXS0102 那类自动方向器件——驱动弱，会被面板侧上拉误判方向）。
  装好后按 datasheet Table 57 做时序：上电复位低电平宽度 tRW1 ≥ 3ms，
  LCD_RST 比 TP_RST 延后 10ms 释放。
"""
import io, re

DTS = ("/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/"
       "arch/arm64/boot/dts/synaptics/dolphin-rdk.dts")
s = io.open(DTS, encoding="utf-8").read()

if "TD7800 复位脚已改为面板侧 3.3V 上拉" in s:
    print("  已改, 跳过"); raise SystemExit

# 把整个 &portb { ...两个 hog... }; 块换成一段解释性注释
m = re.search(r"\n&portb \{\n.*?\n\};\n", s, re.S)
assert m, "找不到 &portb 块"
old = m.group(0)
assert "td7800_lcd_rst_hog" in old and "td7800_tp_rst_hog" in old, "块里没有两个 hog"

new = """
/* TD7800 复位脚已改为面板侧 3.3V 上拉，SoC 不再驱动（2026-07-28）
 *
 * 曾经在这里放过两个 gpio-hog：
 *   td7800_lcd_rst_hog  portb 4 = GPIO36 = pad STS1_VALD = J32.33 = 面板 RESET_N
 *   td7800_tp_rst_hog   portb 6 = GPIO38 = pad STS1_SOP  = J32.32 = 面板 TCH_RESET_N
 * 实测两条 pad 电平分别是 1.57V 和 2.28V，都落在 TD7800 的禁区里：
 *   datasheet Table 44 第6项——RESET_N / TCH_RESET_N 属 IOVCC 域；
 *   Table 50——IOVCC = 2.7~3.6V；Table 51——VIH1 = 0.70 x IOVCC（3.3V 时 >= 2.31V）。
 * 而 SL1680 这组 pad 是 1.8V 域，输出高最多 1.8V，物理上给不出 2.31V。
 * 2.28V = 1.8 + 0.48 = pad 上端 ESD 二极管压降，说明面板侧 3.3V 上拉在往回灌电流。
 * 结果：TDDI 停在不确定复位态——I2C 从机块能应答固件 ID，但触摸引擎不跑、ATTN 永不拉低。
 * 拔掉两根线后中断立刻从 0 跳到 2626，定性确认。
 *
 * 现在两根杜邦线已物理拔除，复位由面板自带的 3.3V 上拉负责（上电即释放）。
 * 显示侧的初始化由 TC358775 的 command 序列 + 面板 NVM 自初始化负责。
 *
 * 要恢复 SoC 控制复位，必须先加 1.8V->3.3V 电平转换（74LVC2T45 固定方向，
 * 或每线 2N7002 + 10k 上拉到 3.3V；不要用 TXB/TXS 自动方向器件）。
 * 装好后按 Table 57 做时序：上电复位低电平宽度 tRW1 >= 3ms，
 * LCD_RST 比 TP_RST 延后 10ms 释放。届时把 hog 换成受控 GPIO，别再用 hog。
 */
"""
s = s.replace(old, new)
io.open(DTS, "w", encoding="utf-8").write(s)

print("  dolphin-rdk.dts 已改")
for k, want in (("td7800_lcd_rst_hog", False), ("td7800_tp_rst_hog", False),
                ("TD7800 复位脚已改为面板侧 3.3V 上拉", True),
                ("synaptics_tcm@2c", True), ("mipirst-gpios", False)):
    ok = (k in s) == want
    print(("  OK  " if ok else "  ERR ") + k + ("  (应有)" if want else "  (应无)"))
