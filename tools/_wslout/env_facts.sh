#!/bin/bash
echo "=== 1. 主机环境 ==="
lsb_release -d 2>/dev/null || cat /etc/os-release | head -2
uname -m
echo "CPU: $(nproc) 核"
free -g | awk '/Mem/{print "内存: "$2"G"}'
df -h /home/astra/sdk 2>/dev/null | tail -1

echo
echo "=== 2. SDK 版本与目录 ==="
cd /home/astra/sdk 2>/dev/null || { echo "SDK 不在"; exit 1; }
git describe --tags 2>/dev/null; git log --oneline -1 2>/dev/null
ls /home/astra/sdk | head -20

echo
echo "=== 3. bblayers.conf ==="
cat build-sl1680/conf/bblayers.conf 2>/dev/null

echo
echo "=== 4. local.conf 里我们改过的部分 ==="
grep -vE "^#|^$" build-sl1680/conf/local.conf 2>/dev/null | head -30

echo
echo "=== 5. 构建产物目录 ==="
ls build-sl1680/tmp/deploy/images/sl1680/ 2>/dev/null | head -15
du -sh build-sl1680/tmp 2>/dev/null
du -sh build-sl1680/downloads 2>/dev/null
du -sh build-sl1680/sstate-cache 2>/dev/null

echo
echo "=== 6. python/工具版本 ==="
python3 --version; git --version | head -1
which bitbake 2>/dev/null || echo "(bitbake 需 source 后可用)"
