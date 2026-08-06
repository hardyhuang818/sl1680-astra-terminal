#!/bin/sh
# webctl 回归：改过路由(新增 /en)，确认中文版和 9 个 API 全都没被打破
B=http://127.0.0.1:8080
c(){ curl -s -o /dev/null -w '%{http_code}' "$@"; }
p(){ curl -s -X POST -H 'Content-Type: application/json' -d "$2" "$B$1"; echo; }

echo "== 路由 =="
echo "  /            -> $(c $B/)            $(curl -s $B/ | grep -c '功能开关') zh-marker"
echo "  /index.html  -> $(c $B/index.html)"
echo "  /en          -> $(c $B/en)          $(curl -s $B/en | grep -c 'SL1680 CONSOLE') en-marker"
echo "  /en/         -> $(c $B/en/)"
echo "  /index_en.html -> $(c $B/index_en.html)"
echo "  /nope        -> $(c $B/nope)  (应为 404)"

echo "== GET API =="
echo "  /api/status          -> $(c $B/api/status)"
echo "  /api/snapshot?t=1    -> $(c "$B/api/snapshot?t=1")"

echo "== POST API (只读/安全的) =="
printf '  /api/volume  '; p /api/volume '{"value":30}'
printf '  /api/mic     '; p /api/mic '{"value":43}'
printf '  /api/servo   '; p /api/servo '{"action":"stop"}'
printf '  /api/panel   '; p /api/panel '{"which":"lighton"}'

echo "== status 关键字段 =="
curl -s $B/api/status | python3 -c "
import sys,json
j=json.load(sys.stdin)
print('  services :', {k:v.get('active') for k,v in j.get('services',{}).items()})
print('  volume   :', j.get('volume'), ' mic:', j.get('mic'))
print('  rails    :', [(r['name'], r['mv']) for r in j.get('rails',[])])
print('  camera   :', j.get('camera'), ' pca9685:', j.get('pca9685'))
print('  touch_irq:', j.get('touch_irq'), ' snapshot_age_s:', j.get('snapshot_age_s'))
print('  log lines:', len(j.get('log',[])))
"
