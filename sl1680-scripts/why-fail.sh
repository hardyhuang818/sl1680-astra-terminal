#!/bin/bash
LOG=~/sdk/build-sl1680/build.log
echo "### unique ERROR: Task failures ###"
grep -E '^ERROR: Task' "$LOG" 2>/dev/null | sed -E 's/[0-9]{4,}//g' | sort -u

echo
echo "### fetch/network errors ###"
grep -E 'do_fetch.*fail|Unable to fetch|FetchError|TLS|gnutls|ExpansionError' "$LOG" 2>/dev/null | sed -E 's/[0-9]{4,}//g' | sort -u | head -10

echo
echo "### latest task progress ###"
grep -oE 'Running task [0-9]+ of [0-9]+' "$LOG" 2>/dev/null | tail -1

echo
echo "### current attempt ###"
grep -E 'bitbake attempt' "$LOG" 2>/dev/null | tail -1
pgrep -af 'bitbake/bin/bitbake' | grep -v pgrep | head -1 >/dev/null && echo "STILL RUNNING" || echo "STOPPED"
