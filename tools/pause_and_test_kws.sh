#!/bin/sh
echo "════ 1. 立刻暂停语音交互 ════"
systemctl stop vision-wake
systemctl stop astra-voice
sleep 2
for s in astra-voice vision-wake astra-translate dl-face; do
  printf "  %-18s %s\n" "$s" "$(systemctl is-active $s)"
done
echo "  麦克风占用: $(fuser /dev/snd/* 2>/dev/null | wc -w) 个进程"

echo
echo "════ 2. 关键词文件到底是中文还是英文 ════"
for f in keywords_astra.txt keywords_astra2.txt keywords_demo.txt; do
  echo "  --- $f"
  cat /home/voice/kws/$f 2>/dev/null | sed 's/^/     /'
done
echo "  --- tokens.txt 前 12 个 token(判断语言)"
head -n 12 /home/voice/kws/tokens.txt 2>/dev/null | tr '\n' ' ' | sed 's/^/     /'
echo

echo
echo "════ 3. 离线测 KWS(用自带的 zh_0.wav，不碰麦克风) ════"
K=/home/voice/kws
/home/voice/bin/sherpa-onnx-keyword-spotter \
  --tokens=$K/tokens.txt \
  --encoder=$K/encoder-epoch-13-avg-2-chunk-16-left-64.int8.onnx \
  --decoder=$K/decoder-epoch-13-avg-2-chunk-16-left-64.onnx \
  --joiner=$K/joiner-epoch-13-avg-2-chunk-16-left-64.int8.onnx \
  --keywords-file=$K/keywords_demo.txt \
  $K/zh_0.wav 2>&1 | tail -n 12 | sed 's/^/  /'
