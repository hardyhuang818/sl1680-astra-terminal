#!/bin/sh
# 模型清单(恢复用)。目录整体汇总，不逐文件展开 espeak-ng-data/dict。
echo "# Astra 模型清单 (板端 /home/voice)"
echo "# 生成: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "# 目录项给的是 tar 内容哈希(顺序固定)，用于校验整份数据是否一致"
echo
for d in sv matcha tts; do
  echo "## $d/  总计 $(du -sh /home/voice/$d 2>/dev/null | cut -f1)"
  for e in /home/voice/$d/*; do
    n=$(basename "$e")
    if [ -d "$e" ]; then
      h=$(cd /home/voice/$d && find "$n" -type f | sort | tar -cf - -T - 2>/dev/null | sha256sum | cut -d' ' -f1)
      printf "  %s  %10s  %s/  (%s 个文件)\n" "$h" "$(du -sb "$e" 2>/dev/null | cut -f1)" "$n" "$(find "$e" -type f | wc -l)"
    else
      printf "  %s  %10s  %s\n" "$(sha256sum "$e" | cut -d' ' -f1)" "$(stat -c %s "$e")" "$n"
    fi
  done
  echo
done
echo "## llm/  总计 $(du -sh /home/voice/llm 2>/dev/null | cut -f1)"
for f in /home/voice/llm/*; do
  n=$(basename "$f")
  case "$n" in
    qwen2.5-0.5b-instruct-q8_0.gguf)
      printf "  %s  %10s  %s  <= 在用\n" "$(sha256sum "$f"|cut -d' ' -f1)" "$(stat -c %s "$f")" "$n" ;;
    *) printf "  %64s  %10s  %s  (未使用)\n" "-" "$(stat -c %s "$f")" "$n" ;;
  esac
done
echo
echo "## bin/  交叉编译产物，不由 recipe 产出"
for f in /home/voice/bin/*; do printf "  %10s  %s\n" "$(stat -c %s "$f")" "$(basename "$f")"; done
