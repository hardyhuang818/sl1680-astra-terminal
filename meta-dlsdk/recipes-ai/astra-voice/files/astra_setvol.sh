#!/bin/sh
aplay -D astraout /home/voice/silent.wav >/dev/null 2>&1
amixer -c dolphinasoc sset AstraVolume "${1:-10%}" >/dev/null 2>&1
exit 0
