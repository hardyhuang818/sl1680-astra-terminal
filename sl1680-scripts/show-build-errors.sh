#!/bin/bash
LOG=~/sdk/build-sl1680/build.log
echo "############ ERROR lines ############"
grep -nE 'ERROR|Fetcher failure|Unable to fetch|not found|No such' "$LOG" | head -40
echo
echo "############ context around first ERROR ############"
grep -n 'ERROR' "$LOG" | head -1 | cut -d: -f1 | while read ln; do
  sed -n "$((ln-3)),$((ln+25))p" "$LOG"
done
echo
echo "############ tim-vx fetch log ############"
FLOG=$(ls -t ~/sdk/build-sl1680/tmp/work/cortexa73-poky-linux/tim-vx/*/temp/log.do_fetch.* 2>/dev/null | head -1)
echo "log: $FLOG"
[ -n "$FLOG" ] && tail -40 "$FLOG"
