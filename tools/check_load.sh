#!/bin/sh
echo "=== 负载 / 开机时长 ==="
uptime | sed 's/^/  /'
echo
echo "=== CPU 占用 TOP (10 秒窗口, /proc/stat 口径) ==="
python3 - <<'PY'
import time,os,re
def snap():
    d={}
    for p in os.listdir('/proc'):
        if not p.isdigit(): continue
        try:
            s=open('/proc/%s/stat'%p).read()
            name=s[s.find('(')+1:s.rfind(')')]
            f=s[s.rfind(')')+2:].split()
            d[p]=(name,int(f[11])+int(f[12]))   # utime+stime
        except Exception: pass
    t=[int(x) for x in open('/proc/stat').readline().split()[1:]]
    return d,sum(t)
a,t0=snap(); time.sleep(10); b,t1=snap()
hz=os.sysconf('SC_CLK_TCK'); dt=(t1-t0)
rows=[]
for p,(n,c) in b.items():
    if p in a:
        d=c-a[p][1]
        if d>0: rows.append((100.0*d/dt*os.sysconf('SC_NPROCESSORS_ONLN'), n, p))
rows.sort(reverse=True)
for pct,n,p in rows[:10]:
    print("  %6.1f%%  %-28s pid=%s" % (pct,n,p))
PY
echo
echo "=== 五个服务 ==="
for s in astra-voice astra-mode astra-translate dl-face vision-wake; do
  printf "  %-18s %s\n" "$s" "$(systemctl is-active $s)"
done
echo
echo "=== astra-mode 现在探到 PC 了吗(它探的就是 192.168.5.166) ==="
journalctl -u astra-mode --no-pager -n 12 -o cat 2>/dev/null | tail -n 5
echo
echo "=== astra-xiaozhi 状态(被 astra-mode 切走的话它会起来) ==="
systemctl is-active astra-xiaozhi 2>/dev/null
