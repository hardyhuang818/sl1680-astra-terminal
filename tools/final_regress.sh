#!/bin/sh
systemctl restart astra-webctl
sleep 2
B=http://127.0.0.1:8080
echo "===== 之前报 Errno 121 的那个调用 ====="
printf '  /api/servo stop -> '; curl -s -X POST -H 'Content-Type: application/json' -d '{"action":"stop"}' $B/api/servo; echo

echo
echo "===== 服务与路由 ====="
echo "  webctl=$(systemctl is-active astra-webctl)  kiosk=$(systemctl is-active astra-kiosk)"
echo "  /   =$(curl -s -o /dev/null -w '%{http_code} %{size_download}B' $B/)"
echo "  /en =$(curl -s -o /dev/null -w '%{http_code} %{size_download}B' $B/en)"
echo "  cog 正在跑: $(for p in /proc/[0-9]*/cmdline; do tr '\0' ' ' < "$p" 2>/dev/null | grep '^/usr/bin/cog'; done)"

echo
echo "===== 面板 ====="
echo "  DRM 模式 : $(dmesg | grep -o 'Set mode: [0-9x]*' | tail -1)"
echo "  触摸中断 : $(grep -i synaptics_tcm /proc/interrupts | awk '{print $2+$3+$4+$5}') 次 (需人手触摸才会增长)"
echo "  触摸驱动 : $(ls /sys/bus/i2c/drivers/synaptics_tcm_i2c/ 2>/dev/null | grep 002c) 已绑定"

echo
echo "===== status 快照 ====="
curl -s $B/api/status | python3 -c "
import sys,json
j=json.load(sys.stdin)
print('  服务    :', ' '.join('%s=%s' % (k, 'on' if v.get('active') else 'off') for k,v in j['services'].items()))
print('  仪表格数:', len(j.get('rails',[])), '条电轨 + 6 项 =', len(j.get('rails',[]))+6, '格 (6列 -> %d 行)' % -(-(len(j.get('rails',[]))+6)//6))
print('  音量/麦 :', j.get('volume'), '/', j.get('mic'))
print('  相机/舵机:', j.get('camera'), '/', j.get('pca9685'))
print('  快照年龄:', j.get('snapshot_age_s'), 's')
"
