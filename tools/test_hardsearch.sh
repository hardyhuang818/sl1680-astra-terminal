#!/bin/sh
# 部署 astra_llm.py 新版并验证"搜索失败不再编造"
set -u
P=/home/voice/astra_llm.py
N=/tmp/astra_llm.py.new

python3 - <<'PYEOF'
d=open("/tmp/astra_llm.py.new","rb").read()
if d[:3]==b"\xef\xbb\xbf":
    d=d[3:]; open("/tmp/astra_llm.py.new","wb").write(d); print("stripped BOM")
src=d.decode("utf-8")
compile(src,"astra_llm.py","exec")
print("语法 OK, %d 字节" % len(d))
for k in ("SEARCH_KEYS_HARD","SEARCH_KEYS_SOFT","is_hard_realtime","不敢瞎说"):
    assert k in src, "缺 "+k
print("新逻辑标记齐全")
PYEOF
[ $? -ne 0 ] && { echo "!! 校验失败，不部署"; exit 1; }

[ -f $P.pre_hardsearch ] || cp $P $P.pre_hardsearch
cp $N $P
chmod +x $P
echo "已部署 -> $P"
echo

. /etc/astra/llm.conf 2>/dev/null
export DEEPSEEK_API_KEY LLM_URL LLM_MODEL ZHIPU_API_KEY

echo "════ 1. 正常联网(回归): 今天广州天气怎么样 ════"
python3 $P "今天广州天气怎么样"
echo
echo "════ 2. 模拟搜索失败 + 硬实时: 今天广州天气怎么样 ════"
echo "   (期望: 老实说查不到，**不许出现任何气温数字**)"
ZHIPU_API_KEY="" python3 $P "今天广州天气怎么样"
echo
echo "════ 3. 模拟搜索失败 + 硬实时: 比特币现在多少钱 ════"
ZHIPU_API_KEY="" python3 $P "比特币现在多少钱"
echo
echo "════ 4. 模拟搜索失败 + 软实时: 最新的人工智能有什么进展 ════"
echo "   (期望: 正常回落到普通问答，不是拒答)"
ZHIPU_API_KEY="" python3 $P "最新的人工智能有什么进展"
echo
echo "════ 5. 非实时问题不受影响: 你是谁 ════"
python3 $P "你是谁"
echo
echo "════ 6. 本地工具层没坏: 现在几点 / 音量多少 ════"
python3 $P "现在几点"
python3 $P "音量多少"
echo
sha256sum $P | cut -d' ' -f1
