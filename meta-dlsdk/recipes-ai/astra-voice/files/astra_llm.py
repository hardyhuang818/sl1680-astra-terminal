#!/usr/bin/env python3
# Astra 云端 LLM 助手 —— astra_voice 用 popen 调它。
# 输入：argv[1] = 用户说的话；可选 --stream 走流式(边生成边按句输出)
# 输出：
#   非流式(默认)：stdout 打印整段回复；退出码 0=成功 非0=失败(调用方回落本地)
#   流式(--stream)：每【一句话】(遇到 。！？.!? 边界)打印一行并 flush，
#                    让 astra_voice 立刻拿去合成播放，不等整段 —— 降感知延迟。
# API key 从环境变量 DEEPSEEK_API_KEY 读，绝不写进代码。只用标准库 urllib。
import sys, os, json, urllib.request, re, subprocess

SYS_PROMPT = ("你是Astra语音助手，用一到两句简短的中文口语回答，不要表情符号不要换行。"
              "不确定或需要实时数据的问题直接说不知道，绝不编造具体数字或事实。")
HARD_ENDS = "。！？!?"   # 强句子边界(总是切)
MIN_SENT  = 4            # 太短的碎片不单独吐(如"1.")，继续累积

# 找 buf 里第一个"可切"的句末位置，找不到返回 -1
def find_boundary(buf):
    for i, ch in enumerate(buf):
        if ch in HARD_ENDS:
            return i
        # ASCII 句点：只有【前一个非空字符不是数字】才算句末(避免 1. 2. 3.14 被切)
        if ch == '.':
            j = i - 1
            while j >= 0 and buf[j] == ' ':
                j -= 1
            if j >= 0 and buf[j].isdigit():
                continue
            return i
    return -1

def build_req(text, stream):
    key = os.environ.get("DEEPSEEK_API_KEY", "").strip()
    if not key:
        sys.stderr.write("no api key"); sys.exit(2)
    url   = os.environ.get("LLM_URL",   "https://api.deepseek.com/v1/chat/completions")
    model = os.environ.get("LLM_MODEL", "deepseek-chat")
    body = {"model": model, "stream": stream, "max_tokens": 150, "temperature": 0.3,
            "messages": [{"role":"system","content":SYS_PROMPT},
                         {"role":"user","content":text}]}
    return urllib.request.Request(url,
        data=json.dumps(body, ensure_ascii=False).encode("utf-8"),
        headers={"Content-Type":"application/json","Authorization":"Bearer "+key})

def run_plain(text):
    try:
        with urllib.request.urlopen(build_req(text, False), timeout=8) as r:
            data = json.load(r)
        msg = data["choices"][0]["message"]["content"].strip().replace("\n"," ")
        if not msg: sys.exit(1)
        print(msg)
    except SystemExit: raise
    except Exception as e:
        sys.stderr.write(str(e)); sys.exit(1)

def run_stream(text):
    buf = ""       # 当前累积、尚未成句的片段
    got = False
    try:
        with urllib.request.urlopen(build_req(text, True), timeout=12) as r:
            for raw in r:                      # 逐行读 SSE
                line = raw.decode("utf-8","ignore").strip()
                if not line.startswith("data:"): continue
                payload = line[5:].strip()
                if payload == "[DONE]": break
                try:
                    obj = json.loads(payload)
                    delta = obj["choices"][0].get("delta",{}).get("content","")
                except Exception:
                    continue
                if not delta: continue
                delta = delta.replace("\n"," ")
                buf += delta
                # 出现句末标点就吐成句部分；太短(如"1.")的继续攒着
                while True:
                    idx = find_boundary(buf)
                    if idx < 0: break
                    cand = buf[:idx+1]
                    alnum = sum(1 for c in cand if c.isalnum())
                    if alnum < MIN_SENT:
                        # 太短，不切，把这个边界并入后文继续攒
                        # 用一个占位避免死循环：把边界符之后的内容拼回去等更长
                        nxt = find_boundary(buf[idx+1:])
                        if nxt < 0: break
                        idx = idx + 1 + nxt
                        cand = buf[:idx+1]
                    sent = cand.strip()
                    buf = buf[idx+1:]
                    if sent:
                        print(sent, flush=True); got = True
        tail = buf.strip()
        if tail:
            print(tail, flush=True); got = True
        if not got: sys.exit(1)
    except SystemExit: raise
    except Exception as e:
        sys.stderr.write(str(e)); sys.exit(1)


# ---- 本地音量控制(拦截，不发给云端) ----
def _vol_get():
    try:
        out = subprocess.check_output(["amixer","-c","dolphinasoc","sget","AstraVolume"],
                                      stderr=subprocess.DEVNULL).decode()
        m = re.search(r"\[(\d+)%\]", out)
        return int(m.group(1)) if m else None
    except Exception:
        return None

def _vol_set(pct):
    pct = max(0, min(100, int(pct)))
    subprocess.call(["amixer","-c","dolphinasoc","sset","AstraVolume","%d%%" % pct],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return pct

def try_volume(text):
    if not any(k in text for k in ["音量","声音","大声","小声","静音","调大","调小","响","轻"]):
        return None
    cur = _vol_get()
    if any(k in text for k in ["多少","几"]) and cur is not None:
        return "当前音量%d%%。" % cur
    if "静音" in text:
        _vol_set(0); return "好的，已静音。"
    m = re.search(r"(\d+)", text)
    if m and any(k in text for k in ["调到","设为","设置","%","到"]):
        return "好的，音量调到%d%%。" % _vol_set(m.group(1))
    if cur is None:
        return None
    if any(k in text for k in ["调大","大声","大一点","大点","高","响"]):
        return "好的，音量调到%d%%。" % _vol_set(cur+15)
    if any(k in text for k in ["调小","小声","小一点","小点","低","轻"]):
        return "好的，音量调到%d%%。" % _vol_set(cur-15)
    return None



# ================= 联网层(实时数据) =================
# 为什么要显式搜索、而不是用模型的"联网"开关：实测智谱 chat 接口挂 web_search
# 工具时 prompt_tokens 只有 21、搜索结果 0 条，模型直接**编**了一个气温出来
# (编的 15~25℃，真实 28~36℃)。所以这里改成：自己调独立搜索 API 拿到真实网页
# 内容，再让 LLM **只根据这些内容**作答，不给它编造的空间。
ZHIPU_SEARCH_URL = "https://open.bigmodel.cn/api/paas/v4/web_search"

# 只有真正需要"此刻的事实"才联网(每次搜索约 ¥0.01, 且多花 2 秒)
#
# 分两档，因为"搜不到"时的正确行为不一样：
#   HARD = 答案本身就是一个此刻的数字/事件。搜不到就**必须闭嘴**，
#          绝不能回落给云端模型 —— 它不知道自己没有今天的数据，会一本正经
#          编出一个气温或股价来。这是被实测抓到过的。
#   SOFT = 只是语气上带"最新/现在"，没有搜到也能凭常识答个大概。
#          搜不到回落到普通问答是安全的。
SEARCH_KEYS_HARD = ("天气", "气温", "下雨", "降雨", "台风", "空气质量", "雾霾", "紫外线",
                    "新闻", "发生了什么", "热搜",
                    "股价", "股票", "大盘", "汇率", "油价", "金价", "比特币")
SEARCH_KEYS_SOFT = ("最新", "实时", "今天的", "现在的", "近况")
SEARCH_KEYS = SEARCH_KEYS_HARD + SEARCH_KEYS_SOFT

def needs_search(text):
    return any(k in text for k in SEARCH_KEYS)

def is_hard_realtime(text):
    """搜不到时是否禁止回落到无实时数据的模型。"""
    return any(k in text for k in SEARCH_KEYS_HARD)

def web_search(query, count=5, timeout=12):
    """返回 [(标题, 内容, 链接), ...]；任何失败返回 []，绝不抛异常。"""
    key = os.environ.get("ZHIPU_API_KEY", "").strip()
    if not key:
        return []
    body = {"search_engine": "search_std", "search_query": query,
            "count": count, "search_recency_filter": "oneDay"}
    req = urllib.request.Request(
        ZHIPU_SEARCH_URL,
        data=json.dumps(body, ensure_ascii=False).encode("utf-8"),
        headers={"Content-Type": "application/json", "Authorization": "Bearer " + key})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            d = json.load(r)
    except Exception as e:
        sys.stderr.write("[search] failed: %s\n" % str(e)[:150])
        return []
    out = []
    for it in (d.get("search_result") or d.get("data") or [])[:count]:
        t = str(it.get("title", ""))[:80]
        c = str(it.get("content", "")).replace("\n", " ")[:300]
        l = str(it.get("link", ""))[:120]
        if c:
            out.append((t, c, l))
    return out

GROUND_PROMPT = (
    "下面是刚刚从网上搜到的实时资料。请**只根据这些资料**回答用户的问题，"
    "用一到两句简短的中文口语，不要表情符号不要换行。"
    "资料里如果有具体数字(气温、价格等)就直接说出来。"
    "如果资料里找不到答案，就直说不知道 —— **绝对不许编造任何数字或事实**。"
)

def answer_with_search(text):
    """联网作答。搜不到就返回 None，让调用方回落到普通问答。"""
    hits = web_search(text)
    if not hits:
        return None
    ctx = "\n".join("- %s：%s" % (t, c) for t, c, _ in hits)
    msgs = [{"role": "system", "content": GROUND_PROMPT},
            {"role": "user", "content": "资料：\n%s\n\n问题：%s" % (ctx, text)}]
    key = os.environ.get("DEEPSEEK_API_KEY", "").strip()
    if not key:
        return None
    url = os.environ.get("LLM_URL", "https://api.deepseek.com/v1/chat/completions")
    model = os.environ.get("LLM_MODEL", "deepseek-chat")
    body = {"model": model, "stream": False, "max_tokens": 200,
            "temperature": 0.2, "messages": msgs}
    req = urllib.request.Request(
        url, data=json.dumps(body, ensure_ascii=False).encode("utf-8"),
        headers={"Content-Type": "application/json", "Authorization": "Bearer " + key})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            d = json.load(r)
        return (d["choices"][0]["message"]["content"] or "").strip().replace("\n", " ") or None
    except Exception as e:
        sys.stderr.write("[search-answer] failed: %s\n" % str(e)[:150])
        return None



# ================= 本地设备工具 =================
# 背景：这些问题以前全丢给云端 LLM，它要么答"我不知道"(时间/温度/内存)，
# 要么**假装执行**("好的已为您打开摄像头监控"其实啥也没干)。都在本地解决。
import datetime, subprocess as _sp

_WD = ["星期一","星期二","星期三","星期四","星期五","星期六","星期日"]

def _read(p, d=""):
    try:
        with open(p) as f: return f.read().strip()
    except Exception: return d

def _cpu_temp():
    for z in ("/sys/class/thermal/thermal_zone0/temp",
              "/sys/class/thermal/thermal_zone1/temp"):
        v = _read(z)
        if v.isdigit():
            t = int(v)
            return t/1000.0 if t > 1000 else float(t)
    return None

def _mem():
    """返回 (已用MB, 总MB)"""
    tot = avail = 0
    for line in _read("/proc/meminfo").splitlines():
        if line.startswith("MemTotal:"):     tot = int(line.split()[1])
        elif line.startswith("MemAvailable:"): avail = int(line.split()[1])
    if not tot: return None
    return (tot - avail)//1024, tot//1024

def _uptime():
    v = _read("/proc/uptime").split()
    if not v: return None
    sec = int(float(v[0]))
    d, r = divmod(sec, 86400); h, r = divmod(r, 3600); m = r//60
    if d: return "%d天%d小时" % (d, h)
    if h: return "%d小时%d分钟" % (h, m)
    return "%d分钟" % m

def _screen_count():
    """dl_face 启动时会打印「发现 N 个 display」，读最近一条。读不到就当单屏。"""
    import re as _re
    try:
        out = _sp.check_output(
            ["journalctl", "-u", "dl-face", "--no-pager", "-n", "80", "-o", "cat"],
            stderr=_sp.DEVNULL).decode("utf-8", "replace")
        m = _re.findall(r"发现 (\d+) 个 display", out)
        if m:
            return max(1, int(m[-1]))
    except Exception:
        pass
    return 1

def _set_screen(mode):
    """切屏幕角色。返回 (成功?, 用的是第几块屏)。
       双屏时监控放【屏1】，对话界面(表情+中英字幕)留在【屏0】；单屏则占屏0。
       camera 模式必须先停 vision-wake —— C920 同时只能被一个进程打开。"""
    n = _screen_count()
    cam = 1 if n >= 2 else 0
    try:
        if mode == "camera":
            _sp.call(["systemctl", "stop", "vision-wake"],
                     stdout=_sp.DEVNULL, stderr=_sp.DEVNULL)
            roles = "0=face\n1=camera\n" if cam == 1 else "0=camera\n"
        else:
            roles = "0=face\n1=face\n"
        open("/tmp/astra_screen_mode.txt", "w").write(roles)
        if mode != "camera":
            _sp.call(["systemctl", "start", "vision-wake"],
                     stdout=_sp.DEVNULL, stderr=_sp.DEVNULL)
        return True, cam
    except Exception as e:
        sys.stderr.write("[screen] %s\n" % str(e)[:120])
        return False, cam


def _rescan_screens():
    """重启 dl-face 重新枚举显示器(便携屏断电后重新上电用)。
       DisplayLink 热插拔回调对显示器断电不触发, 只能整体重扫。"""
    try:
        _sp.call(["systemctl", "restart", "dl-face"],
                 stdout=_sp.DEVNULL, stderr=_sp.DEVNULL)
        return True
    except Exception as e:
        sys.stderr.write("[rescan] %s\n" % str(e)[:120])
        return False

def try_device(text):
    t = text
    # --- 重新检测屏幕(便携屏断电重连后用) ---
    _rescan_kw = ("重新检测", "重新识别", "重新扫描", "刷新屏幕", "重扫屏幕", "屏幕没亮", "屏幕不亮")
    if any(k in t for k in _rescan_kw) or t.strip().strip("。，！？!?,. ") in ("重扫", "重新检测屏幕"):
        if _rescan_screens():
            return "好的，正在重新检测显示器，大约二十秒后屏幕会重新点亮。"
        return "抱歉，重新检测失败了。"
    # --- 屏幕模式(要真的执行) ---
    # 切屏幕必须【动词+名词】同时出现。只匹配"摄像头/监控"太松了 ——
    # 嘈杂环境下 ASR 误识别很容易撞上，屏1 会莫名跳到摄像头画面。
    _CAM_VERBS_ON  = ("打开", "开启", "切到", "切换", "显示", "调出", "看看", "看一下")
    _CAM_VERBS_OFF = ("关闭", "关掉", "退出", "取消", "停止", "关了")
    _CAM_NOUNS     = ("摄像头", "监控", "camera")
    _FACE_NOUNS    = ("表情", "脸")

    _has_cam  = any(n in t for n in _CAM_NOUNS)
    _has_face = any(n in t for n in _FACE_NOUNS)

    # 短指令精确匹配：ASR 经常把开头动词吃掉("打开摄像头" -> "摄像头")。
    # 用【整句去标点后完全相等】判断，"电大监控"这类误识别不会命中。
    _SHORT_CMD = t.strip().strip("。，、！？!?,. \t")
    if _SHORT_CMD in ("摄像头", "监控", "摄像机", "打开摄像头", "打开监控"):
        ok, cam = _set_screen("camera")
        if not ok:
            return "抱歉，切换失败了。"
        where = "第二块屏" if cam == 1 else "屏幕"
        return "好的，已在%s打开监控画面，视觉唤醒先暂停了。" % where
    if _SHORT_CMD in ("表情", "表情脸", "换回表情", "关闭监控", "关摄像头"):
        ok, _ = _set_screen("face")
        return "好的，已切回表情画面，视觉唤醒恢复了。" if ok else "抱歉，切换失败了。"

    if _has_cam and any(v in t for v in _CAM_VERBS_OFF):
        ok, _ = _set_screen("face")
        return "好的，已关闭监控画面，视觉唤醒恢复了。" if ok else "抱歉，切换失败了。"
    if _has_cam and any(v in t for v in _CAM_VERBS_ON):
        ok, cam = _set_screen("camera")
        if not ok:
            return "抱歉，切换失败了。"
        where = "第二块屏" if cam == 1 else "屏幕"
        return "好的，已在%s打开监控画面，视觉唤醒先暂停了。" % where
    if _has_face and any(v in t for v in ("换回", "切回", "回到", "换成", "切换")):
        ok, _ = _set_screen("face")
        return "好的，已切回表情画面，视觉唤醒恢复了。" if ok else "抱歉，切换失败了。"

    # --- 时间 / 日期 ---
    now = datetime.datetime.now()
    if any(k in t for k in ["几点", "现在的时间", "报时"]):
        return "现在是%d点%d分。" % (now.hour, now.minute)
    if any(k in t for k in ["几号", "星期几", "礼拜几", "今天的日期", "日期"]):
        return "今天是%d月%d日，%s。" % (now.month, now.day, _WD[now.weekday()])

    # --- 设备状态 --- (排除天气类问题, 那是"气温"不是 CPU 温度)
    weatherish = any(k in t for k in ["天气", "气温", "室外", "外面", "户外"])
    if not weatherish and any(k in t for k in ["温度", "多热", "烫"]):
        c = _cpu_temp()
        if c is not None:
            return "处理器温度%.0f度，%s。" % (c, "有点高" if c >= 80 else "正常")
    if any(k in t for k in ["内存", "运行内存", "memory"]):
        m = _mem()
        if m:
            return "内存已用%d兆，总共%d兆。" % m
    if any(k in t for k in ["运行多久", "开机多久", "运行了多长", "跑了多久"]):
        u = _uptime()
        if u:
            return "已经运行%s了。" % u
    return None


def main():
    args = [a for a in sys.argv[1:]]
    stream = "--stream" in args
    args = [a for a in args if a != "--stream"]
    text = args[0] if args else ""
    if not text.strip(): sys.exit(3)
    _vr = try_volume(text)
    if _vr is not None:
        print(_vr); sys.exit(0)
    _dr = try_device(text)
    if _dr is not None:
        print(_dr); sys.exit(0)
    if needs_search(text):
        _sr = answer_with_search(text)
        if _sr:
            print(_sr); sys.exit(0)
        # 搜索失败。硬实时问题绝不回落 —— 见 SEARCH_KEYS_HARD 处的说明。
        if is_hard_realtime(text):
            print("我这会儿联网没查到，不敢瞎说，你等下再问我一次吧"); sys.exit(0)
        # 软实时(只是语气带"最新")回落到普通问答是安全的
    if stream: run_stream(text)
    else:      run_plain(text)

if __name__ == "__main__":
    main()
