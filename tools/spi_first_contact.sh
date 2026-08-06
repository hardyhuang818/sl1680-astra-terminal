#!/bin/sh
# EB7928 SPI 首次通信：剥 BOM -> 自检 -> 四种模式扫 IDENTIFY
python3 - <<'EOF'
for p in ('/home/voice/eb7928.py', '/home/voice/eb7928_spi.py'):
    d = open(p, 'rb').read()
    if d[:3] == b'\xef\xbb\xbf':
        open(p, 'wb').write(d[3:]); print('BOM stripped', p)
    else:
        print('clean', p)
EOF
cd /home/voice
echo "===== 离线自检（CRC/组包）====="
python3 eb7928_spi.py selftest 2>&1 | tail -2
echo
echo "===== SS0n pinmux 归属确认 ====="
grep -i "SS0n\|spi" /sys/kernel/debug/pinctrl/f7fe2c10.pinctrl-berlin-pinctrl/pinmux-pins | head -n 4
echo
echo "===== 四种 SPI 模式扫 IDENTIFY ====="
python3 eb7928_spi.py scanmode
