#!/bin/bash
L=/home/astra/sdk/build-sl1680/cog_build.log
echo "=== bitbake 进程数 ==="
ps aux | grep -c "[b]itbake"
echo "=== Summary / ERROR ==="
grep -E "Tasks Summary|^ERROR" "$L" | tail -3
echo "=== 日志最后 3 行 ==="
tail -3 "$L"
echo "=== WebKit .o 文件数 ==="
find /home/astra/sdk/build-sl1680/tmp/work/cortexa73-poky-linux/wpewebkit -name "*.o" 2>/dev/null | wc -l
echo "=== ninja 还在跑吗 ==="
ps aux | grep -c "[n]inja"
