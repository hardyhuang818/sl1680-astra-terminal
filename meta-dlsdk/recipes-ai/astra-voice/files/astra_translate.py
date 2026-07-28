#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
astra_translate.py —— Astra 中英对照字幕翻译守护进程 (SL1680 / DL7400)

读: /tmp/astra_status.txt   (astra_voice 写, 整文件覆盖, 我们绝不碰它)
      STATE=listening|thinking|speaking|paused|offline
      HEARD=<中文>
      REPLY=<中文>
写: /tmp/astra_status_en.txt  (原子替换, dl_face 读)
      HEARD_EN=<english>
      REPLY_EN=<english>

设计要点:
  * 主循环只做「读文件 / 比对 / 写文件」, 永不做网络 IO —— 翻译在两个独立
    worker 线程里跑 (HEARD 一个、REPLY 一个), 谁先回来谁先落盘。
  * 中文原文 -> 英文 的 LRU 缓存 (默认 200 条)。astra_voice 每次状态变化都会
    重写整个状态文件, 同一句中文会被反复看到, 缓存命中时 0 延迟 0 费用。
  * 任何失败 (无 key / 无网 / 超时 / 返回异常) 都只是把该字段留空, 不崩溃、
    不阻塞、不刷屏重试。
  * 只用 python 标准库 (板子上没有 pip)。

环境变量 (systemd EnvironmentFile=-/etc/astra/llm.conf):
  DEEPSEEK_API_KEY / LLM_URL / LLM_MODEL   —— 与 astra_llm.py 完全一致
  可选: ASTRA_STATUS, ASTRA_STATUS_EN, TRANSLATE_MODEL, ASTRA_TR_DEBUG=1
"""

import json
import os
import signal
import sys
import tempfile
import threading
import time
import urllib.request
from collections import OrderedDict

# ---------------------------------------------------------------- 可调参数
STATUS_IN = os.environ.get("ASTRA_STATUS", "/tmp/astra_status.txt")
STATUS_OUT = os.environ.get("ASTRA_STATUS_EN", "/tmp/astra_status_en.txt")

POLL_S = 0.20            # 轮询状态文件周期
# 每个字段独立去抖：
#   HEARD 有 ~10 秒展示窗口(thinking 全程)，可以稳一下躲开 ASR 中间结果。
#   REPLY 只在 STATE=speaking 期间显示(约 2-4 秒, 说完 astra_voice 立刻清空)，
#   再去抖就彻底来不及上屏 —— 所以 0 延迟, 一出现立刻翻。
DEBOUNCE = {"HEARD": 0.35, "REPLY": 0.0}
# REPLY 是"逐句流式"写的: astra_voice 每合成一句就把 REPLY 改成更长的前缀。
# 每个前缀都翻一次既费钱又永远追不上, 所以: 首次立刻翻, 之后只有"停止增长"
# 这么久才翻最终版。
GROW_SETTLE_S = 1.2
HTTP_TIMEOUT = 8.0       # 单次请求超时
MAX_TOKENS = 80          # 一行字幕足够了
TEMPERATURE = 0.2
CACHE_MAX = 200          # LRU 上限, 长跑设备内存有界
ATTEMPTS = 2             # 一次任务内最多试 2 次(网络抖动)
RETRY_GAP_S = 1.5        # 两次尝试之间隔多久
FAIL_COOLDOWN_S = 30.0   # 彻底失败后, 若该句仍在屏幕上, 30s 后再试一次
MAX_OUT_BYTES = 480      # dl_face 侧缓冲是 512B / fgets 600B, 留余量

SYS_PROMPT = (
    "You are a subtitle translator. Translate the user's Chinese text into "
    "concise, natural spoken English. Output ONLY the translation: no quotes, "
    "no pinyin, no notes, no explanation, no trailing punctuation beyond what a "
    "spoken line needs. Keep it short enough to fit on one subtitle line."
)

DEBUG = os.environ.get("ASTRA_TR_DEBUG", "") not in ("", "0")


def log(msg):
    sys.stderr.write("[astra_translate] %s\n" % msg)
    sys.stderr.flush()


def dbg(msg):
    if DEBUG:
        log(msg)


# ---------------------------------------------------------------- 文本清洗
_QUOTES = "\"'“”‘’「」『』"


def one_line(s, limit=MAX_OUT_BYTES):
    """去掉换行/制表/控制字符, 压空白, 按 UTF-8 边界截断 —— 保证 dl_face 那边
    一行一个字段、缓冲区放得下, 也堵死了从 ASR/LLM 文本注入换行的可能。"""
    if not s:
        return ""
    s = "".join(" " if (ch < " " or ch == "\x7f") else ch for ch in s)
    s = " ".join(s.split())
    # 模型偶尔会把译文整句加引号
    while len(s) >= 2 and s[0] in _QUOTES and s[-1] in _QUOTES:
        s = s[1:-1].strip()
    low = s.lower()
    for pre in ("translation:", "english:"):
        if low.startswith(pre):
            s = s[len(pre):].strip()
            break
    b = s.encode("utf-8")
    if len(b) > limit:
        s = b[:limit].decode("utf-8", "ignore").rstrip()
    return s


# ---------------------------------------------------------------- LRU 缓存
class LruCache(object):
    def __init__(self, cap):
        self._cap = cap
        self._d = OrderedDict()
        self._lk = threading.Lock()

    def get(self, k):
        with self._lk:
            if k in self._d:
                self._d.move_to_end(k)
                return self._d[k]
        return None

    def put(self, k, v):
        with self._lk:
            self._d[k] = v
            self._d.move_to_end(k)
            while len(self._d) > self._cap:
                self._d.popitem(last=False)


CACHE = LruCache(CACHE_MAX)

# 翻译和 astra_voice 共用同一个 API key/额度, 而 astra_voice 在 STATE=thinking
# 期间正开着流式补全。这里把翻译限制成"最多 1 个在途请求", 避免把语音主链路
# 挤到限流(一旦 429, astra_voice 会回落到本地 0.5B 或规则话术, 得不偿失)。
API_SEM = threading.Semaphore(1)


# ---------------------------------------------------------------- 翻译调用
def translate_once(zh):
    """成功返回英文字符串, 失败返回 None。绝不抛异常。"""
    key = os.environ.get("DEEPSEEK_API_KEY", "").strip()
    if not key:
        return None
    url = os.environ.get("LLM_URL", "https://api.deepseek.com/v1/chat/completions")
    model = os.environ.get("TRANSLATE_MODEL") or os.environ.get("LLM_MODEL", "deepseek-chat")
    body = {
        "model": model,
        "stream": False,
        "max_tokens": MAX_TOKENS,
        "temperature": TEMPERATURE,
        "messages": [
            {"role": "system", "content": SYS_PROMPT},
            {"role": "user", "content": zh},
        ],
    }
    req = urllib.request.Request(
        url,
        data=json.dumps(body, ensure_ascii=False).encode("utf-8"),
        headers={"Content-Type": "application/json",
                 "Authorization": "Bearer " + key},
    )
    try:
        with API_SEM:                           # 同一时刻最多 1 个翻译请求
            with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as r:
                data = json.load(r)
        ch = data["choices"][0]
        # 被 max_tokens 截断的译文看起来像完整句子, 宁可不显示也不显示半句
        if ch.get("finish_reason") == "length":
            dbg("translation truncated by max_tokens, dropped")
            return None
        en = one_line(ch["message"]["content"])
        return en or None
    except Exception as e:                      # 网络/超时/HTTP错/JSON错 一视同仁
        dbg("translate failed (%s): %r" % (type(e).__name__, str(e)[:160]))
        return None


# ---------------------------------------------------------------- worker
class Worker(threading.Thread):
    """每个字段一个线程。只保留「最新一次」请求 —— 中间被跳过的旧句子不值得花钱。"""

    def __init__(self, field, on_result):
        threading.Thread.__init__(self, name="tr-" + field, daemon=True)
        self.field = field
        self._on_result = on_result
        self._cv = threading.Condition()
        self._pending = None
        self._stop = False

    def submit(self, zh):
        with self._cv:
            self._pending = zh
            self._cv.notify()

    def stop(self):
        with self._cv:
            self._stop = True
            self._cv.notify()

    def _superseded(self):
        with self._cv:
            return self._stop or self._pending is not None

    def run(self):
        while True:
            with self._cv:
                while self._pending is None and not self._stop:
                    self._cv.wait()
                if self._stop:
                    return
                zh = self._pending
                self._pending = None

            en = CACHE.get(zh)
            if en is None:
                for i in range(ATTEMPTS):
                    en = translate_once(zh)
                    if en or self._superseded():
                        break
                    if i + 1 < ATTEMPTS:
                        time.sleep(RETRY_GAP_S)     # 只睡 worker 线程, 主循环照跑
                if en:
                    CACHE.put(zh, en)
            try:
                self._on_result(self.field, zh, en)
            except Exception as e:
                log("on_result error: %r" % e)


# ---------------------------------------------------------------- 状态
class Field(object):
    __slots__ = ("zh", "seen_at", "requested", "retry_at", "en", "prev_req")

    def __init__(self):
        self.zh = ""          # 状态文件里当前的中文
        self.seen_at = 0.0    # 这段中文第一次被看到的时间(去抖用)
        self.requested = None # 已经提交给 worker / 已命中缓存 的中文
        self.retry_at = 0.0   # >0 表示翻译失败, 到点可重试
        self.en = ""          # 当前输出的英文
        # 上一次真正发出去翻译的中文。**中文变化时不清空** —— 专门用来判断
        # 新文本是不是旧文本的"更长前缀"(REPLY 逐句流式增长)。
        self.prev_req = ""


FIELDS = OrderedDict([("HEARD", Field()), ("REPLY", Field())])
STATE_LK = threading.Lock()     # 保护 FIELDS
WRITE_LK = threading.Lock()     # 保护落盘 (加锁顺序: WRITE_LK -> STATE_LK)
_last_written = None
WORKERS = {}


# ---------------------------------------------------------------- 读状态文件
_clear_pending = {"HEARD": 0, "REPLY": 0}   # 「非空->空」需连看两次, 防撕裂读


def read_status():
    """返回 {'HEARD':..., 'REPLY':...}; 读失败(非 ENOENT)返回 None 表示本轮跳过。
    astra_voice 是整文件覆盖写, 可能读到写了一半的文件 ——
    所以只认「以 \\n 结尾的完整行」, 半行直接丢弃。"""
    try:
        with open(STATUS_IN, "r", encoding="utf-8", errors="replace") as f:
            raw = f.read()
    except FileNotFoundError:
        return {"HEARD": "", "REPLY": ""}
    except Exception as e:
        dbg("read status failed: %r" % e)
        return None

    out = {"HEARD": "", "REPLY": ""}
    for line in raw.splitlines(True):
        if not line.endswith("\n"):
            continue                     # 撕裂的末行, 不要
        line = line[:-1].rstrip("\r")
        for k in out:
            pre = k + "="
            if line.startswith(pre):
                out[k] = line[len(pre):].strip()
    return out


# ---------------------------------------------------------------- 写输出文件
def write_atomic(path, text):
    d = os.path.dirname(path) or "."
    fd, tmp = tempfile.mkstemp(prefix=".astra_en.", suffix=".tmp", dir=d)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(text)
            fh.flush()
            os.fsync(fh.fileno())
        os.chmod(tmp, 0o644)
        os.replace(tmp, path)            # 原子: dl_face 永远读不到半截文件
        return True
    except Exception as e:
        log("write %s failed: %r" % (path, e))
        try:
            os.unlink(tmp)
        except OSError:
            pass
        return False


def emit():
    """内容有变才写。主循环和两个 worker 都会调它 —— 任一字段就绪立刻落盘。"""
    global _last_written
    with WRITE_LK:
        with STATE_LK:
            h, r = FIELDS["HEARD"], FIELDS["REPLY"]
            # 同时写出「这段英文对应的中文原文」当关联键。两个文件是各自独立
            # 更新的, 中文换了而英文还没跟上时会有个几百毫秒的窗口 ——
            # dl_face 拿 SRC 和当前中文比对, 不一致就只显示中文, 绝不错配。
            text = ("HEARD_EN=%s\nHEARD_SRC=%s\nREPLY_EN=%s\nREPLY_SRC=%s\n"
                    % (h.en, h.zh if h.en else "",
                       r.en, r.zh if r.en else ""))
        if text == _last_written:
            return
        if write_atomic(STATUS_OUT, text):
            _last_written = text
            dbg("wrote: " + text.replace("\n", " | "))


def on_result(field, zh, en):
    """worker 回调。译文晚到但中文已经换了 -> 丢弃, 绝不让中英错配。"""
    with STATE_LK:
        f = FIELDS[field]
        if f.zh != zh:
            dbg("stale result for %s, dropped" % field)
            return
        if en:
            f.en = en
            f.retry_at = 0.0
        else:
            f.retry_at = time.monotonic() + FAIL_COOLDOWN_S
            return
    emit()


# ---------------------------------------------------------------- 主循环
_running = True


def _sigterm(_sig, _frm):
    global _running
    _running = False


def tick():
    now = time.monotonic()
    st = read_status()
    if st is None:
        return

    to_submit = []
    with STATE_LK:
        for name, f in FIELDS.items():
            zh = one_line(st.get(name, ""))

            # 非空 -> 空: 要求连续看到两次, 躲开 astra_voice 覆盖写的空窗
            if not zh and f.zh:
                if _clear_pending[name] < 1:
                    _clear_pending[name] += 1
                    continue
            _clear_pending[name] = 0

            if zh != f.zh:
                f.zh = zh
                f.seen_at = now
                f.requested = None
                f.retry_at = 0.0
                f.en = ""                       # 中文换了, 旧英文立刻作废
                if zh:
                    hit = CACHE.get(zh)
                    if hit:                     # 缓存命中 = 0 延迟 0 费用
                        f.en = hit
                        f.requested = zh
                        f.prev_req = zh
                else:
                    f.prev_req = ""             # 一轮说完了, 下一轮重新判断增长
                continue

            if not zh:
                continue
            if f.requested != zh:
                # REPLY 是逐句流式写的(每合成一句就把 REPLY 换成更长的前缀)。
                # 首次出现 -> 立刻翻(英文早点上屏, speaking 窗口很短);
                # 之后只是"变长了" -> 等它停止增长再翻最终版, 否则每句付一次钱
                # 还永远追不上。
                grow = bool(f.prev_req) and zh != f.prev_req and zh.startswith(f.prev_req)
                need = GROW_SETTLE_S if grow else DEBOUNCE.get(name, 0.35)
                if now - f.seen_at >= need:
                    f.requested = zh
                    f.prev_req = zh
                    to_submit.append((name, zh))
            elif f.retry_at and now >= f.retry_at:
                f.retry_at = 0.0
                to_submit.append((name, zh))

    for name, zh in to_submit:
        dbg("submit %s: %s" % (name, zh[:40]))
        WORKERS[name].submit(zh)

    emit()


def main():
    signal.signal(signal.SIGTERM, _sigterm)
    signal.signal(signal.SIGINT, _sigterm)

    if not os.environ.get("DEEPSEEK_API_KEY", "").strip():
        # 不退出: 退出会被 Restart=always 拉成重启风暴。空跑并保持输出为空,
        # dl_face 就只显示中文, 不会显示过期英文。
        log("DEEPSEEK_API_KEY not set — running idle (English will stay empty)")

    for name in FIELDS:
        w = Worker(name, on_result)
        w.start()
        WORKERS[name] = w

    emit()      # 开机先落一个空文件, dl_face 有东西可读

    log("started: %s -> %s (poll %.0fms, cache %d)"
        % (STATUS_IN, STATUS_OUT, POLL_S * 1000, CACHE_MAX))

    while _running:
        try:
            tick()
        except Exception as e:                  # 主循环绝不因任何异常退出
            log("tick error: %r" % e)
        time.sleep(POLL_S)

    for w in WORKERS.values():
        w.stop()
    log("stopped")
    return 0


if __name__ == "__main__":
    sys.exit(main())
