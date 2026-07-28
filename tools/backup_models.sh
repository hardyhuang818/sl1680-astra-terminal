#!/bin/sh
# 把 /home/voice 打包，供烧新镜像后恢复。
# 这是唯一没有 PC 副本的东西 —— rootfs 一烧就没了。
set -u
OUT=/home/voice_backup
mkdir -p $OUT

echo "════ 打包(分目录，方便按需恢复) ════"
cd /home/voice || exit 1
for d in sv matcha tts kws bin; do
  [ -d "$d" ] || continue
  f=$OUT/voice_$d.tar.gz
  if [ -f "$f" ]; then echo "  已存在，跳过: voice_$d.tar.gz"; continue; fi
  printf "  打包 %-8s ... " "$d/"
  tar czf "$f" "$d" 2>/dev/null && echo "$(du -h $f | cut -f1)" || echo "失败"
done

# llm 单独处理：1.4G 里只有一个在用，另两个是选型残留
echo "  打包 llm/ (只打在用的那个模型)"
f=$OUT/voice_llm_inuse.tar.gz
if [ -f "$f" ]; then echo "    已存在，跳过"
else
  tar czf "$f" llm/qwen2.5-0.5b-instruct-q8_0.gguf 2>/dev/null && echo "    $(du -h $f | cut -f1)"
fi

# 脚本和配置(小，一起带上)
echo "  打包 脚本+配置"
tar czf $OUT/voice_scripts.tar.gz *.py *.sh 2>/dev/null
tar czf $OUT/etc_astra.tar.gz -C / etc/astra etc/asound.conf 2>/dev/null
echo "    $(du -h $OUT/voice_scripts.tar.gz | cut -f1) + $(du -h $OUT/etc_astra.tar.gz | cut -f1)"

echo
echo "════ 校验和 ════"
cd $OUT && sha256sum *.tar.gz > SHA256SUMS.txt
cat SHA256SUMS.txt | sed 's/^/  /'

echo
echo "════ 结果 ════"
ls -l $OUT | awk 'NR>1{printf "  %11s  %s\n",$5,$9}'
echo "  合计: $(du -sh $OUT | cut -f1)"
echo "  剩余空间: $(df -h /home | tail -1 | awk '{print $4}')"
