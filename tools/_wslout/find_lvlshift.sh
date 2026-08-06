#!/bin/bash
K=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source
D=$K/arch/arm64/boot/dts/synaptics/dolphin-rdk.dts
echo "=== dts 里的 levelshift_en ==="
grep -n -B6 -A10 -i "levelshift" "$D"
echo
echo "=== 原理图里 Levershift_EN 与 TXB0108 的关系 ==="
python3 - <<'PYEOF'
import io, re, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
try:
    from pypdf import PdfReader
except ImportError:
    from PyPDF2 import PdfReader
r = PdfReader("/mnt/d/Claude code/Case6_Astra/SL1680/SC950-000798-01 RevF/SC950-000798-01 RevF.pdf")
t = r.pages[3].extract_text() or ""
for ln in t.splitlines():
    if re.search(r"Lever|Level.*EN|TXB0108|OE|VCCA|VCCB", ln, re.I):
        print("   ", ln.strip()[:120])
PYEOF
