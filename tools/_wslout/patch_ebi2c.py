#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""给 EB7928 加一条内核态 GPIO-I2C 私有总线（不动硬件，只改 DTB）

背景：EB7928 固定在 0x40，而 SL1680 每条硬件 I2C 的 0x40 都有原住民
（i2c-0 INA3221 / i2c-1,2 TPS62870 / i2c-3,4 INA220）。用户态 GPIO bit-bang
验证了链路可通（0x40 稳定 ACK、包头 CRC-6 通过），但 Python 翻 sysfs GPIO 的
位周期抖动导致长包必错——扫 16 组时序参数最好只有 3/4 且不单调。

解法：用内核自带的 i2c-gpio 驱动（板子上 gpioi2c3/i2c-7 就是同一个驱动），
在 J32.32/33 这两个空闲脚上再开一条总线。内核态 bit-bang 时序确定性远高于用户态。

引脚（v3.0 移除 TD7800 复位 hog 后空出，pad 已 mux 为 gpio）：
  SDA = portb 6 = GPIO38 = pad STS1_SOP  = J32.32
  SCL = portb 4 = GPIO36 = pad STS1_VALD = J32.33

注意：这两个 pad 是 1.8V 域、未过电平转换。开漏用法下 SoC 只拉低不驱高，
高电平由模块侧 3.3V 上拉提供，EB7928(3.3V 域)的 VIH 得到满足；
SoC 侧经 ESD 二极管注入约 0.1mA/线。**临时测试可接受，长期需加电平转换。**
"""
import io, re

DTS = ("/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/"
       "arch/arm64/boot/dts/synaptics/dolphin-rdk.dts")
s = io.open(DTS, encoding="utf-8").read()

if "ebi2c" in s:
    print("  已改, 跳过"); raise SystemExit

# 挂在已有的 gpioi2c3 节点后面，形式完全照抄它
anchor = """	gpioi2c3: gpioi2c3 {"""
assert s.count(anchor) == 1, "找不到 gpioi2c3 节点"

new = """	/* EB7928 (Synaptics Smart Bridge, 固定 I2C 0x40) 的私有总线。
	 * 它的地址不可改，而本板每条硬件 I2C 的 0x40 都已被占用
	 * (i2c-0 INA3221 / i2c-1,2 TPS62870 / i2c-3,4 INA220)，
	 * 故用内核 i2c-gpio 在两个空闲脚上单开一条，避免返修摘芯片。
	 *   SDA = portb 6 = GPIO38 = pad STS1_SOP  = J32.32
	 *   SCL = portb 4 = GPIO36 = pad STS1_VALD = J32.33
	 * (这两个 pad 在 v3.0 移除 TD7800 复位 hog 后空出，mux 已是 gpio)
	 * ⚠ pad 为 1.8V 域未过电平转换：开漏下 SoC 只拉低，高电平由模块侧
	 *   3.3V 上拉给出；SoC 侧经 ESD 二极管注入约 0.1mA/线，临时测试可接受。
	 * delay-us=5 => 约 100kHz，与 gpioi2c3 一致。
	 */
	ebi2c: ebi2c {
		#address-cells = <1>;
		#size-cells = <0>;
		compatible = "i2c-gpio";
		gpios = <&portb 6 GPIO_ACTIVE_HIGH /* sda */
			 &portb 4 GPIO_ACTIVE_HIGH /* scl */
			>;
		i2c-gpio,delay-us = <5>;
		i2c-gpio,timeout-ms = <100>;
	};

	gpioi2c3: gpioi2c3 {"""

s = s.replace(anchor, new)
io.open(DTS, "w", encoding="utf-8").write(s)
print("  dolphin-rdk.dts 已改")
for k in ("ebi2c", "i2c-gpio", "portb 6", "portb 4"):
    print(("  ✓ " if k in s else "  ✗ ") + k)
