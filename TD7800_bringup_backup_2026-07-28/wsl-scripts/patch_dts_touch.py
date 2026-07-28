#!/usr/bin/env python3
# dolphin-rdk.dts: &i2c0 加 TD7800 触摸节点 (tcm2, INT=porta10=J32.12, 无reset-gpio)
DTS = "/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts"
src = open(DTS, encoding="utf-8").read()
if "synaptics_tcm@2c" in src:
    print("已有 tcm 节点, 跳过")
else:
    old = """	rpi_panel_regulator: rpi_panel_regulator@45 {
		compatible = "raspberrypi,7inch-touchscreen-panel-regulator";
		reg = <0x45>;
		gpio-controller;
		#gpio-cells = <2>;
	};
};"""
    new = """	rpi_panel_regulator: rpi_panel_regulator@45 {
		compatible = "raspberrypi,7inch-touchscreen-panel-regulator";
		reg = <0x45>;
		gpio-controller;
		#gpio-cells = <2>;
	};

	/* TD7800 TDDI touch (TM10.5 panel). TP I2C rides TW0 via J32.3/5.
	 * INT = TP_INT -> J32.12 = pad I2S2_DI1 func0 = GPIO10 = porta line 10
	 * (empirically confirmed: ATTN latches low, releases after I2C drain).
	 * NO reset-gpio on purpose: TDDI reset would kill the display; TP_RST
	 * and panel RESX are tied high in hardware.
	 * 0x2008 = IRQF_ONESHOT | IRQF_TRIGGER_LOW.
	 */
	synaptics_tcm@2c {
		compatible = "synaptics,tcm-i2c";
		reg = <0x2c>;
		status = "okay";
		interrupt-parent = <&porta>;
		interrupts = <10 0x2008>;
		synaptics,irq-gpio = <&porta 10 0x2008>;
		synaptics,irq-flags = <0x2008>;
		synaptics,irq-on-state = <0>;
		synaptics,power-delay-ms = <200>;
		synaptics,chunks = <1024 1024>;
		synaptics,command-timeout-ms = <3000>;
		synaptics,command-polling-ms = <20>;
		synaptics,command-turnaround-us = <50 100>;
		synaptics,command-retry-ms = <10>;
		synaptics,fw-switch-delay-ms = <100>;
	};
};"""
    assert src.count(old) == 1, "i2c0 rpi_panel_regulator 块匹配异常"
    src = src.replace(old, new)
    open(DTS, "w", encoding="utf-8").write(src)
    print("OK: tcm 节点已加入 i2c0")
chk = open(DTS, encoding="utf-8").read()
for k in ("synaptics_tcm@2c", "interrupt-parent = <&porta>", "interrupts = <10 0x2008>"):
    print(("✓" if k in chk else "✗"), k)
