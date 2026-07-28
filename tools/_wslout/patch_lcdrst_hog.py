#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""LCD_RESET 从 VPP 驱动接管改为 gpio-hog 常拉高

现象：给 vpp 加 mipirst-gpios 后驱动确实接管了，但实测停在
  gpio-516 (mipi) out lo ACTIVE LOW   ← 逻辑1 = 复位置位
即复位一直按着 —— 触摸引擎开机跑了几百个中断后就被按住，摸屏幕零报点。
VPP 只在特定路径调 set_gpio_val(0) 释放，我们的显示链路(DSI→TC358775→LVDS)
走不到那条路径。

改法（与 TP_RST 一致，Case44/RK3568 验证过的做法）：
  TDDI 的复位脚不要交给驱动管，用 gpio-hog 上电即常拉高、独占。
  显示复位由 TC358775 桥片侧的初始化序列负责，不需要 SoC 参与。
"""
import io, re

DTS = "/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts"
s = io.open(DTS, encoding="utf-8").read()
if "td7800_lcd_rst_hog" in s:
    print("  已改, 跳过"); raise SystemExit

# 1) 移除 vpp 的 mipirst-gpios（连同注释）
m = re.search(r"\n\t\t/\* LCD_RESET（J32 pin33.*?\*/\n\t\tmipirst-gpios = <&portb 4 GPIO_ACTIVE_LOW>;", s, re.S)
assert m, "找不到 mipirst-gpios 块"
s = s[:m.start()] + s[m.end():]

# 2) 把 LCD_RESET 加进已有的 hog 块
old = '''&portb {
	td7800_tp_rst_hog {'''
new = '''&portb {
	/* LCD_RESET（J32 pin33 = portb4 = GPIO36）
	 * 曾试过交给 VPP 驱动的 mipirst-gpios，实测它停在"复位置位"状态
	 * (out lo + ACTIVE_LOW)，把触摸引擎按死。我们的显示链路是
	 * DSI→TC358775→LVDS，走不到 VPP 释放复位的那条路径。
	 * 改用 hog 常拉高：显示侧的复位/初始化由桥片 command 序列负责。
	 */
	td7800_lcd_rst_hog {
		gpio-hog;
		gpios = <4 GPIO_ACTIVE_HIGH>;
		output-high;
		line-name = "td7800-lcd-rst";
	};

	td7800_tp_rst_hog {'''
assert s.count(old) == 1
s = s.replace(old, new)

io.open(DTS, "w", encoding="utf-8").write(s)
print("  dolphin-rdk.dts 已改")
for k, want in (("td7800_lcd_rst_hog", True), ("td7800_tp_rst_hog", True),
                ("mipirst-gpios", False)):
    ok = (k in s) == want
    print(("  ✓ " if ok else "  ✗ ") + k + ("(应有)" if want else "(应无)"))
