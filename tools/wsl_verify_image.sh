#!/bin/bash
O="/mnt/d/Claude code/Case6_Astra/tools/_wslout"; mkdir -p "$O"
R='/mnt/d/Claude code/Case6_Astra/meta-dlsdk'
rsync -a --delete --delete-excluded \
  --exclude='*.repo_stale_*' --exclude='*.pre_selfheal' --exclude='*.orig' --exclude='*DANGEROUS*' \
  "$R/" /home/astra/sdk/meta-dlsdk/
cd /home/astra/sdk
set +e
source poky/oe-init-build-env build-sl1680 >/dev/null 2>&1

echo "════ 1. bbappend 被识别了吗 ════"
bitbake-layers show-appends 2>/dev/null | grep -A3 "astra-media" | head -n 6 | sed 's/^/  /'

echo
echo "════ 2. packagegroup 能解析吗 ════"
bitbake -e packagegroup-astra-terminal > /tmp/pg.txt 2>/tmp/pg.err
if [ $? -ne 0 ]; then echo "  ❌ 解析失败"; grep ERROR /tmp/pg.err | head -n 5 | sed 's/^/    /'
else
  echo "  ✅ 解析通过"
  grep -m1 "^RDEPENDS:packagegroup-astra-terminal=" /tmp/pg.txt | sed 's/^/    /'
fi

echo
echo "════ 3. ★ astra-media 的 IMAGE_INSTALL 里出现了吗 ════"
bitbake -e astra-media > /tmp/im.txt 2>/tmp/im.err
if [ $? -ne 0 ]; then echo "  ❌ 解析失败"; grep ERROR /tmp/im.err | head -n 5 | sed 's/^/    /'
else
  echo "  ASTRA_TERMINAL_PACKAGES = $(grep -m1 '^ASTRA_TERMINAL_PACKAGES=' /tmp/im.txt | cut -d'"' -f2)"
  echo "  IMAGE_INSTALL 里的相关项:"
  grep -m1 "^IMAGE_INSTALL=" /tmp/im.txt | tr ' ' '\n' | grep -iE "astra|dl-face|sherpa|packagegroup-astra" | sort -u | sed 's/^/    /'
fi

echo
echo "════ 4. ★ 依赖能不能全部解出(最能抓错的一步) ════"
bitbake -n packagegroup-astra-terminal > "$O/pgn.log" 2>&1
if [ $? -eq 0 ]; then
  echo "  ✅ packagegroup 任务图可生成"
  grep "Tasks Summary" "$O/pgn.log" | tail -n 1 | sed 's/^/    /'
else
  echo "  ❌"; grep -E "ERROR|Nothing (PROVIDES|RPROVIDES)" "$O/pgn.log" | head -n 8 | sed 's/^/    /'
fi

echo
echo "════ 5. astra-voice 新增的 synap 依赖能否解析 ════"
bitbake -n astra-voice > "$O/avn.log" 2>&1
if [ $? -eq 0 ]; then echo "  ✅ astra-voice 依赖完整"
else grep -E "ERROR|Nothing RPROVIDES" "$O/avn.log" | head -n 6 | sed 's/^/    /'; fi
