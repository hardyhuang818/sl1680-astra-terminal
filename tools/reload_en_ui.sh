#!/bin/sh
# 剥 BOM -> 重启 kiosk -> 确认加载的是 /en 且页面完整
python3 - <<'EOF'
p='/home/voice/webctl/index_en.html'
d=open(p,'rb').read()
if d[:3]==b'\xef\xbb\xbf':
    open(p,'wb').write(d[3:]); print('BOM stripped ->', len(d)-3)
else:
    print('clean', len(d))
EOF
systemctl restart astra-kiosk
sleep 7
echo "kiosk  : $(systemctl is-active astra-kiosk)"
echo "webctl : $(systemctl is-active astra-webctl)"
echo "served : $(curl -s -o /dev/null -w '%{http_code} %{size_download}B' http://127.0.0.1:8080/en)"
echo "sanity : viewport=$(curl -s http://127.0.0.1:8080/en | grep -c 'width=1280') tglpad=$(curl -s http://127.0.0.1:8080/en | grep -c 'top:-5px') thumb=$(curl -s http://127.0.0.1:8080/en | grep -c 'slider-thumb')"
echo "--- kiosk journal ---"
journalctl -u astra-kiosk --since '-30s' --no-pager | tail -6
