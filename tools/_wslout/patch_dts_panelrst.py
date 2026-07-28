#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""配置 TD7800 面板的两根复位线（用户接线：J32.32=TP_RST, J32.33=LCD_RESET）

上电时序（用户给定）：3.3V 与 TP_RESET 同时上电；LCD_RST 延后 10ms。

映射（已验证）：portb line N = SoC GPIO (32+N)，标定点 vol_up=portb6=STS1_SOP=GPIO38
  TP_RST     J32.32  pad STS1_SOP   GPIO38  <&portb 6>
  LCD_RESET  J32.33  pad STS1_VALD  GPIO36  <&portb 4>

⚠ 冲突处理：portb6 原本是 volume_up 实体键（配成输入+中断 → TP_RST 浮空 → 触摸芯片
   被按在复位态，这正是 2026-07-28 触摸失效的根因）。本项目音量走语音控制，
   实体 volume_up 无用，故移除；vol_down 保留。
"""
import io

DTS = "/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts"
s = io.open(DTS, encoding="utf-8").read()
if "td7800_tp_rst_hog" in s:
    print("  已配置, 跳过"); raise SystemExit

# ── 1) 移除 vol_up（它占着 TP_RST 的 pad）──
old_vol = '''		vol_up {
			label = "volume_up";
			gpio = <&portb 6 GPIO_ACTIVE_HIGH>;
			linux,code = <KEY_VOLUMEUP>;
			linux,can-disable;
			debounce-interval = <15>;
		};

'''
assert s.count(old_vol) == 1, "vol_up 块匹配失败"
s = s.replace(old_vol, '''		/* volume_up 已移除：它占用 portb6(pad STS1_SOP = J32 pin32)，
		 * 而本板把 J32.32 接到 TD7800 面板的 TP_RST。键被 gpio-keys 配成
		 * 输入+中断 → TP_RST 浮空 → 触摸芯片一直处于复位/未定义态。
		 * 本项目音量由语音控制，实体键无用。vol_down 保留。
		 */

''')

# ── 2) pinmux：把两根复位脚也复用成 gpio ──
old_pmux = '''	vol_key_pmux: vol-key-pmux {
		groups = "STS1_SOP", "STS1_CLK";
		function = "gpio";'''
new_pmux = '''	vol_key_pmux: vol-key-pmux {
		/* STS1_SOP  = GPIO38 = J32.32 = 面板 TP_RST   (下方 gpio-hog 常拉高)
		 * STS1_VALD = GPIO36 = J32.33 = 面板 LCD_RESET(交给 vpp 的 mipirst)
		 * STS1_CLK  = GPIO39 = vol_down
		 * 三个 pad 都要复用成 gpio；本组由 gpio_keys 节点在早期应用。 */
		groups = "STS1_SOP", "STS1_VALD", "STS1_CLK";
		function = "gpio";'''
assert s.count(old_pmux) == 1, "vol_key_pmux 匹配失败"
s = s.replace(old_pmux, new_pmux)

# ── 3) TP_RST：gpio-hog 上电即拉高（与 3.3V 同步，用户给定时序）──
HOG = '''
/* ─────────────────────────────────────────────────────────────
 * TD7800 面板 TP_RST（J32 pin32 = portb6 = GPIO38）
 * 用户硬件时序：3.3V 与 TP_RESET 同时上电 —— 这里用 gpio-hog 让内核
 * 在 GPIO 控制器 probe 时立即驱动高并独占，之后谁也改不了。
 * 参考 Case44(RK3568) 同款做法：TDDI 的复位脚不要交给触摸驱动管，
 * 否则显示初始化时它还没拉高 → 屏和触摸互相死锁。
 * ⚠ TD7800 是 TDDI：这根线复位的是整颗芯片(含显示驱动)。
 * ───────────────────────────────────────────────────────────── */
&portb {
	td7800_tp_rst_hog {
		gpio-hog;
		gpios = <6 GPIO_ACTIVE_HIGH>;
		output-high;
		line-name = "td7800-tp-rst";
	};
};
'''
s = s.rstrip() + "\n" + HOG

# ── 4) LCD_RESET：交给 vpp 驱动的 mipirst（probe 拉低→初始化释放，天然满足 10ms 延后）──
import re
m = re.search(r"(&avio \{\n(?:.*\n)*?\tvpp \{\n)", s)
assert m, "找不到 &avio/vpp 节点"
ins = ('''\t\t/* LCD_RESET（J32 pin33 = portb4 = GPIO36）交给 VPP 驱动：
\t\t * probe 时 GPIOD_OUT_LOW，显示初始化时 avio_module_mipirst_set_gpio_val(0)
\t\t * 释放；suspend 再拉回。ACTIVE_LOW 使"逻辑1=复位"对应物理低电平。
\t\t * 内核起来才释放 → 天然晚于 TP_RST 与 3.3V（满足 LCD_RST 延后 10ms 的要求）。
\t\t * 之前 dmesg 一直打印 "MIPI Rst GPIO not found" 就是因为缺这条属性。 */
\t\tmipirst-gpios = <&portb 4 GPIO_ACTIVE_LOW>;
''')
s = s[:m.end()] + ins + s[m.end():]

io.open(DTS, "w", encoding="utf-8").write(s)
print("  dolphin-rdk.dts 已配置面板复位线")
for k in ("td7800_tp_rst_hog", "mipirst-gpios = <&portb 4", '"STS1_SOP", "STS1_VALD", "STS1_CLK"'):
    print(("  ✓ " if k in s else "  ✗ ") + k)
print(("  ✓ " if "volume_up" not in s else "  ✗ ") + "vol_up 已移除")
