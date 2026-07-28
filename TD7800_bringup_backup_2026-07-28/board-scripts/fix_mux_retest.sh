#!/bin/sh
echo "=== 改 pinmux: SDO/SDI -> spi2 ==="
echo "改前: $(devmem 0xf7fe2c14)"
devmem 0xf7fe2c14 32 0x00005A01
echo "改后: $(devmem 0xf7fe2c14)"
python3 - "$(devmem 0xf7fe2c14)" <<'EOF'
import sys
v = int(sys.argv[1], 16)
for name, off in (("SS0n", 3), ("SDO", 15), ("SDI", 18), ("SCLK", 21)):
    print("  SM_SPI2_%-5s func=%d" % (name, (v >> off) & 7))
EOF
