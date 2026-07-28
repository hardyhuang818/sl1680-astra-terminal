#!/bin/sh
echo "════ 本次开机 astra-voice 的启停历史 ════"
journalctl -u astra-voice --no-pager -o short-iso -b 2>/dev/null \
  | grep -E "Started|Stopping|Stopped|Scheduled restart|Failed|Main process exited|Deactivated" \
  | sed 's/ sl1680 systemd\[1\]:/ |/' | sed 's/^/  /'

echo
echo "════ 崩溃/异常退出的原因(如果有) ════"
journalctl -u astra-voice --no-pager -o cat -b 2>/dev/null \
  | grep -iE "Protocol error|Device or resource busy|cannot open|hw params|段错误|Segmentation|core dump|错误|失败" \
  | sort | uniq -c | sort -rn | head -n 8 | sed 's/^/  /'
echo "  (空 = 没有报错，都是正常启停)"

echo
echo "════ 谁登录过 / 有没有别的 SSH 会话 ════"
who 2>/dev/null | sed 's/^/  /'
last -n 8 2>/dev/null | head -n 8 | sed 's/^/  /'
echo "  当前 sshd 会话数: $(pgrep -c sshd 2>/dev/null)"

echo
echo "════ 13:44 前后系统里发生了什么 ════"
journalctl --no-pager -o short-iso --since "13:43:30" --until "13:45:30" 2>/dev/null \
  | grep -vE "astra_voice\[|astra_translate|dl_face\[" | tail -n 20 | sed 's/^/  /'
