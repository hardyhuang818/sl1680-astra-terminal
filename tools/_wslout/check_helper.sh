#!/bin/bash
K=/home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source/drivers/input/touchscreen
echo "════ 1. 触摸驱动源码位置 ════"
find $K -maxdepth 2 -name "syna_tcm2.h" -o -maxdepth 2 -name "syna_tcm2.c" 2>/dev/null | head -4
find /home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source -name "syna_tcm2.h" 2>/dev/null | head -2
echo
D=$(dirname $(find /home/astra/sdk/build-sl1680/tmp/work-shared/sl1680/kernel-source -name "syna_tcm2.h" 2>/dev/null | head -1))
echo "驱动目录: $D"
echo
echo "════ 2. ENABLE_HELPER 现状 ════"
grep -n "ENABLE_HELPER" $D/syna_tcm2.h 2>/dev/null | head -5
echo
echo "════ 3. 其它相关开关 ════"
grep -nE "^#define (ENABLE_|RESET_ON_RESUME|REPORT_|POWER_ALIVE|FORCE_CONNECT)" $D/syna_tcm2.h 2>/dev/null | head -20
echo
echo "════ 4. 自发复位处理函数 ════"
grep -n "process_unexpected_reset" $D/syna_tcm2.c 2>/dev/null | head -5
grep -n -A12 "static void syna_dev_process_unexpected_reset" $D/syna_tcm2.c 2>/dev/null | head -20
