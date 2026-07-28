#!/bin/sh
echo "=== A. gpio debugfs 裸dump ==="
head -n 40 /sys/kernel/debug/gpio 2>/dev/null || echo "(空/不存在)"
echo
echo "=== B. avio 时钟全览 ==="
grep -iE "avio|vpll|dsi|dphy" /sys/kernel/debug/clk/clk_summary 2>/dev/null
echo
echo "=== C. fxl6408 扩展器寄存器直读 (i2c-3 0x43: reg3=方向 reg5=输出) ==="
for r in 1 3 5 7; do
  v=$(i2cget -f -y 3 0x43 $r 2>/dev/null)
  echo "  reg$r = $v"
done
echo "(bit1=PWR_ON_DSI/背光使能, bit5=CSI用, bit7=GPIO_DSI)"
