#!/bin/bash
# Extract net labels / signal names from the SL1680 RDK IO schematic PDF.
PDF="/mnt/d/Claude code/Case6_Astra/SL1680/SC950-000798-01 RevE-L16X0 RDK IO SCHEMATIC BOARD.pdf"
OUT=/tmp/sl1680-sch.txt

pdftotext -layout "$PDF" "$OUT" 2>/dev/null
echo "=== total lines: $(wc -l < "$OUT") ==="
echo
echo "############ pages count ############"
pdfinfo "$PDF" 2>/dev/null | grep -iE 'Pages|Title'
echo
echo "############ DSI / MIPI nets ############"
grep -niE 'dsi|mipi' "$OUT" | head -40
echo
echo "############ TOUCH / TP / INT / RESET nets ############"
grep -niE 'touch|tp_|tp-|_tp|reset|_int|attn' "$OUT" | head -40
echo
echo "############ I2C nets ############"
grep -niE 'i2c|scl|sda' "$OUT" | head -40
echo
echo "############ LVDS / panel / backlight nets ############"
grep -niE 'lvds|panel|backlight|bl_|lcd|pwm' "$OUT" | head -40
