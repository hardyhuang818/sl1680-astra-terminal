#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ebi2c v2：换到已过板载电平转换的 3.3V 脚，并补上 GPIO_OPEN_DRAIN 标志

v1 的问题（实测）：
  用的 portb 6/4 (STS1_SOP/VALD, J32.32/33) 是**裸 1.8V pad，未过 TXB0108**。
  EVK 的 10K 上拉到 3.3V 灌进来，实测线上只有 1.02V —— SL1680 侧还有个约 4.5K
  的对地负载在分压((3.3-1.02)/10K=0.23mA, 1.02/0.23m≈4.5K)。
  1.02V 低于 1.8V 逻辑的 VIH(1.17V)，总线永远读不到合法高电平。

v2 改用 SM_SPI2_SS0n / SS1n：
  - 原理图确认有 V3P3.SPI2_SS0n / V3P3.SPI2_SS1n 网络 => J32 侧经 TXB0108 是 3.3V 域
  - dts 里无人 mux（grep 计数 0），确认空闲
  - 与 EVK 的 3.3V VDDIO_HOST 电平域完全匹配，不再有 ESD 注入/钳位问题

  SDA = SM GPIO16 = gpio624 = pad SM_SPI2_SS1n = J32.26
  SCL = SM GPIO17 = gpio625 = pad SM_SPI2_SS0n = J32.24

另外补 GPIO_OPEN_DRAIN 标志：v1 内核启动时抱怨
  "gpio-518 (ebi2c): enforced open drain please flag it properly in DT"
且实测空闲时两条线被驱动成 out lo（开漏总线空闲应释放为高阻），补上标志消除歧义。
"""
import io, re

DTS = ("/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/"
       "arch/arm64/boot/dts/synaptics/dolphin-rdk.dts")
s = io.open(DTS, encoding="utf-8").read()

# 定位 v1 的 ebi2c 块并整体替换
m = re.search(r"\n\t/\* EB7928 .*?\n\tebi2c: ebi2c \{.*?\n\t\};\n", s, re.S)
assert m, "找不到 v1 的 ebi2c 块"

new = """
	/* EB7928 (Synaptics Smart Bridge, 固定 I2C 0x40) 的私有总线。
	 * 它的地址不可改，而本板每条硬件 I2C 的 0x40 都已被占用
	 * (i2c-0 INA3221 / i2c-1,2 TPS62870 / i2c-3,4 INA220)，
	 * 故用内核 i2c-gpio 在两个空闲脚上单开一条，避免返修摘芯片。
	 *
	 * ★ 必须用**已过板载 TXB0108 电平转换**的脚（原理图有 V3P3.xxx 网络），
	 *   J32 侧才是 3.3V，与 EVK 的 VDDIO_HOST(出厂默认 3.3V) 匹配。
	 *   曾用 portb 6/4 (STS1_SOP/VALD, J32.32/33) —— 那是**裸 1.8V pad**，
	 *   EVK 的 10K 上拉灌进来实测只有 1.02V(SL1680 侧约 4.5K 对地负载分压)，
	 *   低于 1.8V 逻辑 VIH(1.17V)，总线读不到合法高电平。
	 *
	 *   SDA = SM GPIO16 = pad SM_SPI2_SS1n = J32.26
	 *   SCL = SM GPIO17 = pad SM_SPI2_SS0n = J32.24
	 *   (portd = SM gpiochip, base 608; 两脚 dts 内无人 mux, 已确认空闲)
	 *
	 * GPIO_OPEN_DRAIN 必须显式声明：不写内核会打
	 *   "enforced open drain please flag it properly in DT"，
	 *   且实测空闲时线被驱成 out lo(开漏总线空闲应为高阻)。
	 * delay-us=5 => 约 100kHz，与 gpioi2c3 一致。
	 */
	ebi2c: ebi2c {
		#address-cells = <1>;
		#size-cells = <0>;
		compatible = "i2c-gpio";
		gpios = <&portd 16 GPIO_OPEN_DRAIN /* sda = J32.26 */
			 &portd 17 GPIO_OPEN_DRAIN /* scl = J32.24 */
			>;
		i2c-gpio,delay-us = <5>;
		i2c-gpio,timeout-ms = <100>;
	};
"""
s = s[:m.start()] + new + s[m.end():]

# 这两个 pad 要 mux 成 gpio：加一个 pmux 组并挂到 ebi2c 节点
if "ebi2c_pmux" not in s:
    anchor = "\tgpioi2c3_pmux: gpioi2c3-pmux {"
    assert s.count(anchor) == 1, "找不到 gpioi2c3_pmux 锚点"
    pmux = """	/* EB7928 私有 I2C 的两个 pad 复用成 gpio（drive-strength 跟 gpioi2c3 一致） */
	ebi2c_pmux: ebi2c-pmux {
		groups = "SM_SPI2_SS1n", "SM_SPI2_SS0n";
		function = "gpio";
		drive-strength = <7>;
	};

"""
    s = s.replace(anchor, pmux + anchor)
    s = s.replace("\t\tcompatible = \"i2c-gpio\";\n\t\tgpios = <&portd 16",
                  "\t\tcompatible = \"i2c-gpio\";\n\t\tpinctrl-names = \"default\";\n"
                  "\t\tpinctrl-0 = <&ebi2c_pmux>;\n\t\tgpios = <&portd 16")

io.open(DTS, "w", encoding="utf-8").write(s)
print("  dolphin-rdk.dts 已改为 v2")
for k, want in (("portd 16", True), ("portd 17", True), ("GPIO_OPEN_DRAIN", True),
                ("ebi2c_pmux", True), ("SM_SPI2_SS1n", True),
                ("&portb 6 GPIO_ACTIVE_HIGH /* sda */", False)):
    ok = (k in s) == want
    print(("  OK  " if ok else "  ERR ") + k + ("" if want else " (应无)"))
