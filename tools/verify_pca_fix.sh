#!/bin/sh
python3 - <<'EOF'
p='/home/voice/pca9685.py'
d=open(p,'rb').read()
if d[:3]==b'\xef\xbb\xbf':
    open(p,'wb').write(d[3:]); print('BOM stripped ->', len(d)-3)
else: print('clean', len(d))
EOF
echo "===== scan（应当只认 0x70，不再误判 0x44）====="
python3 /home/voice/pca9685.py scan 2>&1 | tail -12
