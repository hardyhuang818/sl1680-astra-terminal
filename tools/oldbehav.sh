#!/bin/sh
. /etc/astra/llm.conf 2>/dev/null
export DEEPSEEK_API_KEY LLM_URL LLM_MODEL
echo "════ 旧版(.pre_hardsearch) 搜索失败时的实际行为 ════"
for q in "今天广州天气怎么样" "比特币现在多少钱"; do
  echo "--- $q"
  ZHIPU_API_KEY="" python3 /home/voice/astra_llm.py.pre_hardsearch "$q"
done
