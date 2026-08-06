#!/bin/sh
# 剥 BOM -> 解析核对 -> 后台烧录（nohup 防 ssh 断线），日志落 /tmp/eb_flash.log
python3 - <<'EOF'
p = '/home/voice/fw_target.hex'
d = open(p, 'rb').read()
if d[:3] == b'\xef\xbb\xbf':
    open(p, 'wb').write(d[3:]); print('BOM stripped ->', len(d)-3)
else:
    print('clean', len(d))
EOF
cd /home/voice
echo "===== 解析核对 ====="
python3 eb7928_spi.py parse fw_target.hex | tail -4
echo
echo "===== 烧录（后台）====="
rm -f /tmp/eb_flash.log
nohup python3 eb7928_spi.py flash fw_target.hex --yes > /tmp/eb_flash.log 2>&1 &
echo "PID $!  日志: /tmp/eb_flash.log"
sleep 8
head -n 20 /tmp/eb_flash.log
