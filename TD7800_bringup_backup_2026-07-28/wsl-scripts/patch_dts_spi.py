#!/usr/bin/env python3
# dolphin-rdk.dts 追加 &spi0 (SM SPI2, J32.19/21/23/24) + spidev
DTS = "/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts"
src = open(DTS, encoding="utf-8").read()
if "&spi0" in src:
    print("已有 &spi0 节点, 跳过")
else:
    src += """
/* SM SPI2 out to J32 pins 19(SDO)/21(SDI)/23(CLK)/24(SS0n).
 * Pads default to spi2 function at reset - no pinmux node needed.
 * spidev for TD7800 display SPI bring-up (9-bit DCX frames from userspace).
 */
&spi0 {
	status = "okay";
	spidev@0 {
		compatible = "rohm,dh2228fv";
		reg = <0>;
		spi-max-frequency = <1000000>;
	};
};
"""
    open(DTS, "w", encoding="utf-8").write(src)
    print("OK: &spi0 + spidev 已追加")
chk = open(DTS, encoding="utf-8").read()
print("spi0:", "&spi0 {" in chk, "| spidev:", "rohm,dh2228fv" in chk, "| td7800 command 仍在:", "0x9C 0x04 0x31" in chk)
