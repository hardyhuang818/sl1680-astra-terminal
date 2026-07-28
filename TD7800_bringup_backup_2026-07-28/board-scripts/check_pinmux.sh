#!/bin/sh
# SM pinctrl 基址 f7fe2c10, 组定义(驱动表):
#   SM_SPI2_SS0n reg+0x4 bits[5:3]    期望0=spi2
#   SM_SPI2_SDO  reg+0x4 bits[17:15]  期望0=spi2
#   SM_SPI2_SDI  reg+0x4 bits[20:18]  期望0=spi2
#   SM_SPI2_SCLK reg+0x4 bits[23:21]  期望0=spi2
V=$(devmem 0xf7fe2c14 2>/dev/null)
echo "raw f7fe2c14 = $V"
python3 - "$V" <<'EOF'
import sys
v = int(sys.argv[1], 16)
for name, off in (("SS0n", 3), ("SDO", 15), ("SDI", 18), ("SCLK", 21)):
    f = (v >> off) & 7
    print("  SM_SPI2_%-5s func=%d %s" % (name, f, "(spi2 ✓)" if f == 0 else "(不是spi2!)"))
EOF
echo
echo "── DW SPI 控制器时钟/状态: 读版本寄存器 ──"
devmem 0xf7fcA05C 2>/dev/null || echo "(读不到)"
