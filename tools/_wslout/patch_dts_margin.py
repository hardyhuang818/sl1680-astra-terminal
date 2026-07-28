#!/usr/bin/env python3
# 三合一: 1) LVCFG PCLKDIV 3->4  2) Byte_clk 48975->65300  3) SM SPI2 SDO/SDI pinmux 固化
DTS = "/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts"
src = open(DTS, encoding="utf-8").read()
orig = src

# 1) Byte_clk
old = "Byte_clk = <48975>;"
new = "Byte_clk = <65300>;\t/* DSIclk 261.2MHz: 带宽+33%余量, LVDS pclk=261.2/4=65.3MHz */"
assert src.count(old) == 1, "Byte_clk 匹配异常"
src = src.replace(old, new)

# 2) LVCFG 0x31 -> 0x41 (PCLKDIV=4)
old = "0x29 0x06 0x9C 0x04 0x31 0x00 0x00 0x00"
new = "0x29 0x06 0x9C 0x04 0x41 0x00 0x00 0x00"
assert src.count(old) == 1, "LVCFG 匹配异常"
src = src.replace(old, new)

# 3) SPI2 SDO/SDI pinmux (U-Boot 把它们复用成 uart2 流控, 必须夺回)
if "spi2_data_pmux" not in src:
    src += """
/* U-Boot leaves SM_SPI2_SDO/SDI muxed as uart2 RTS/CTS - reclaim for spi2.
 * SCLK/SS0n already default to spi2 (function 0).
 */
&sm_pinctrl {
	spi2_data_pmux: spi2-data-pmux {
		groups = "SM_SPI2_SDO", "SM_SPI2_SDI";
		function = "spi2";
	};
};
"""
    old = """&spi0 {
	status = "okay";
	spidev@0 {"""
    new = """&spi0 {
	status = "okay";
	pinctrl-names = "default";
	pinctrl-0 = <&spi2_data_pmux>;
	spidev@0 {"""
    assert src.count(old) == 1, "spi0 节点匹配异常"
    src = src.replace(old, new)

open(DTS, "w", encoding="utf-8").write(src)
print("OK 补丁完成")
for k in ("Byte_clk = <65300>", "0x41 0x00 0x00 0x00", "spi2_data_pmux", "pinctrl-0 = <&spi2_data_pmux>"):
    print(("✓" if k in src else "✗"), k)
