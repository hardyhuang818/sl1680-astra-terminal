#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""SL1680 Web 控制台 —— 板端 API 服务（M1）

设计约束（都是这块板的实际情况）：
  - 只用 python3 标准库（板上无 pip，3.12.9 自带 http.server/json/subprocess 足够）
  - 所有动作走白名单，不提供任意命令执行
  - busybox 环境：无 pkill/pgrep -f 不可靠 → 找 PID 用 systemctl show -p MainPID
  - 不提供"重启板子"（软复位不可靠，需人工断电——做成按钮只会误导）

用法:  python3 /home/voice/webctl/astra_webctl.py   (监听 0.0.0.0:8080)
服务:  astra-webctl.service
"""
import ctypes, json, os, re, signal, subprocess, threading, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = 8080
ROOT = os.path.dirname(os.path.abspath(__file__))
INDEX = os.path.join(ROOT, "index.html")

# ── 白名单 ────────────────────────────────────────────────────────────
SERVICES = ["astra-voice", "vision-wake", "dl-face", "astra-timer", "dl-clock"]
SERVICE_ACTIONS = ["start", "stop", "enable", "disable"]
# DLSDK 单进程独占：起一个前先停另一个
MUTEX = {"dl-face": "dl-clock", "dl-clock": "dl-face"}

SETVOL = next((p for p in ("/usr/bin/astra_setvol.sh", "/home/voice/astra_setvol.sh")
               if os.path.exists(p)), None)
PCA = next((p for p in ("/home/voice/pca9685.py",) if os.path.exists(p)), None)

STATE_FILE = "/tmp/webctl_state.json"          # 记住最后设置的音量等（重启丢失无妨）
_state_lock = threading.Lock()


def sh(cmd, timeout=10):
    """跑一条白名单内部命令，返回 (rc, stdout+stderr)"""
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, (r.stdout or "") + (r.stderr or "")
    except subprocess.TimeoutExpired:
        return -1, "timeout"
    except Exception as e:
        return -1, str(e)


def load_state():
    try:
        return json.load(open(STATE_FILE))
    except Exception:
        return {}


def save_state(**kw):
    with _state_lock:
        st = load_state()
        st.update(kw)
        try:
            json.dump(st, open(STATE_FILE, "w"))
        except Exception:
            pass


def svc_pid(name):
    rc, out = sh(["systemctl", "show", "-p", "MainPID", "--value", name], 5)
    try:
        pid = int(out.strip())
        return pid if pid > 0 else None
    except ValueError:
        return None


# ── 状态采集 ──────────────────────────────────────────────────────────

def read_rails():
    """板载 INA3221：只认有 label 的 in1/2/3（总线电压 mV）+ 对应 currN(mA)。
    in4/5/6 是分流电压，会随负载大幅波动，绝不能当电压看（踩过一次）。"""
    rails = []
    base = "/sys/class/hwmon"
    try:
        hs = sorted(os.listdir(base))
    except OSError:
        return rails
    for h in hs:
        p = os.path.join(base, h)
        try:
            if "ina3221" not in open(p + "/name").read():
                continue
        except OSError:
            continue
        for i in (1, 2, 3):
            try:
                label = open("%s/in%d_label" % (p, i)).read().strip()
                mv = int(open("%s/in%d_input" % (p, i)).read())
            except OSError:
                continue
            ma = None
            try:
                ma = int(open("%s/curr%d_input" % (p, i)).read())
            except OSError:
                pass
            rails.append({"name": label, "mv": mv, "ma": ma})
    return rails


def touch_irq():
    try:
        for ln in open("/proc/interrupts"):
            if "synaptics_tcm" in ln:
                return sum(int(x) for x in ln.split()[1:5] if x.isdigit())
    except OSError:
        pass
    return None


def pca_present():
    """只读探测 All Call 0x70 的 MODE1，无副作用"""
    try:
        libc = ctypes.CDLL(None, use_errno=True)
        fd = os.open("/dev/i2c-0", os.O_RDWR)
        try:
            if libc.ioctl(fd, ctypes.c_ulong(0x0703), ctypes.c_ulong(0x70)) < 0:
                return False
            os.write(fd, bytes([0x00]))
            os.read(fd, 1)
            return True
        finally:
            os.close(fd)
    except Exception:
        return False


def recent_log():
    """对话流：astra-voice + vision-wake 的关键行，按时间混排"""
    lines = []
    rc, out = sh(["journalctl", "-u", "astra-voice", "-n", "40",
                  "--no-pager", "-o", "short"], 6)
    for ln in out.splitlines():
        if re.search(r"\[(你|机器|唤醒|跳过|存)\s*\]", ln):
            lines.append(ln)
    rc, out = sh(["journalctl", "-u", "vision-wake", "-n", "10",
                  "--no-pager", "-o", "short"], 6)
    for ln in out.splitlines():
        if "[vwake]" in ln:
            lines.append(ln)
    lines.sort(key=lambda s: s[:15])           # "Aug 05 14:02:11" 前缀可排序
    return [re.sub(r"\s+sl1680\s+\S+\[\d+\]:", "", l) for l in lines[-30:]]


def vwake_boxheight():
    rc, out = sh(["journalctl", "-u", "vision-wake", "-n", "8", "--no-pager"], 5)
    m = None
    for ln in out.splitlines():
        g = re.search(r"框高=(\d+)%", ln)
        if g:
            m = int(g.group(1))
    return m


def collect_status():
    st = load_state()
    svcs = {}
    for s in SERVICES:
        rc, act = sh(["systemctl", "is-active", s], 4)
        rc, ena = sh(["systemctl", "is-enabled", s], 4)
        svcs[s] = {"active": act.strip() == "active", "enabled": ena.strip() == "enabled"}
    mem = {}
    try:
        for ln in open("/proc/meminfo"):
            k, v = ln.split(":")
            if k in ("MemTotal", "MemAvailable"):
                mem[k] = int(v.strip().split()[0])
    except OSError:
        pass
    try:
        up = float(open("/proc/uptime").read().split()[0])
    except OSError:
        up = 0
    try:
        vfs = os.statvfs("/")
        disk_pct = round(100 * (1 - vfs.f_bavail / vfs.f_blocks))
    except OSError:
        disk_pct = None
    try:
        load1 = float(open("/proc/loadavg").read().split()[0])
    except OSError:
        load1 = None
    snap = None
    if os.path.exists("/tmp/vw_cur.jpg"):
        snap = round(time.time() - os.path.getmtime("/tmp/vw_cur.jpg"), 1)
    return {
        "time": time.strftime("%H:%M:%S"),
        "uptime_s": int(up),
        "services": svcs,
        "rails": read_rails(),
        "mem_total_kb": mem.get("MemTotal"),
        "mem_avail_kb": mem.get("MemAvailable"),
        "disk_used_pct": disk_pct,
        "load1": load1,
        "touch_irq": touch_irq(),
        "camera": os.path.isdir("/dev/v4l/by-id") and any(
            "C920" in f for f in os.listdir("/dev/v4l/by-id")),
        # 渐移进行中不去碰芯片——状态探针和舵机写会抢 I2C 寄存器指针，
        # 偶发把 MODE1 读歪成"带 EXTCLK"触发一次无害但多余的自动重初始化
        "pca9685": True if _servo_busy else pca_present(),
        "volume": st.get("volume"),
        "mic": st.get("mic"),
        "vwake_box": vwake_boxheight(),
        "snapshot_age_s": snap,
        "log": recent_log(),
    }


# ── 动作 ──────────────────────────────────────────────────────────────

def act_service(name, action):
    if name not in SERVICES + ["weston"] :
        return False, "服务不在白名单"
    if name == "weston":
        if action != "restart":
            return False, "weston 只允许 restart"
        rc, out = sh(["systemctl", "restart", "weston"], 20)
        return rc == 0, out.strip()
    if action not in SERVICE_ACTIONS:
        return False, "动作不在白名单"
    if action == "start" and name in MUTEX:
        sh(["systemctl", "stop", MUTEX[name]], 15)     # DLSDK 独占互斥
    rc, out = sh(["systemctl", action, name], 20)
    return rc == 0, out.strip()


def act_volume(v):
    v = max(0, min(100, int(v)))
    if not SETVOL:
        return False, "astra_setvol.sh 不存在"
    rc, out = sh(["sh", SETVOL, str(v)], 10)
    if rc == 0:
        save_state(volume=v)
    return rc == 0, out.strip()[-200:]


def act_mic(v):
    v = max(0, min(100, int(v)))
    # 找有 Mic 控制的声卡（卡号会变，不能写死）
    for card in range(0, 4):
        rc, out = sh(["amixer", "-c", str(card), "sget", "Mic"], 4)
        if rc == 0 and "Capture" in out:
            rc2, out2 = sh(["amixer", "-c", str(card), "sset", "Mic", "%d%%" % v], 5)
            if rc2 == 0:
                save_state(mic=v)
                return True, "card %d" % card
    return False, "没找到带 Mic 控制的声卡"


def act_say(text):
    text = text.strip()[:200]
    if not text:
        return False, "空文本"
    pid = svc_pid("astra-voice")
    if not pid:
        return False, "astra-voice 没在跑"
    try:
        open("/tmp/astra_say.txt", "w", encoding="utf-8").write(text)
        os.kill(pid, signal.SIGUSR2)
        return True, "ok"
    except Exception as e:
        return False, str(e)


def act_wake():
    pid = svc_pid("astra-voice")
    if not pid:
        return False, "astra-voice 没在跑"
    try:
        os.kill(pid, signal.SIGUSR1)
        return True, "ok"
    except Exception as e:
        return False, str(e)


_servo_busy = set()                            # 渐移一次要几秒，别让并发请求打架


def act_servo(body):
    if not PCA:
        return False, "pca9685.py 不存在"
    a = body.get("action", "angle")
    if a == "move":
        ch = int(body.get("ch", 0)); deg = int(body.get("deg", 90))
        dps = max(5, min(360, int(body.get("dps", 60))))
        if not (0 <= ch <= 15 and 0 <= deg <= 180):
            return False, "参数越界"
        if ch in _servo_busy:
            return False, "CH%d 上一个动作还在走" % ch
        _servo_busy.add(ch)
        try:
            rc, out = sh(["python3", PCA, "move", str(ch), str(deg), str(dps)], 45)
        finally:
            _servo_busy.discard(ch)
        return rc == 0, out.strip()[-200:]
    if a == "angle":
        ch = int(body.get("ch", 0)); deg = int(body.get("deg", 90))
        if not (0 <= ch <= 15 and 0 <= deg <= 180):
            return False, "参数越界"
        rc, out = sh(["python3", PCA, "angle", str(ch), str(deg)], 10)
    elif a == "loop":
        ch = int(body.get("ch", 0)); sec = min(600, int(body.get("sec", 60)))
        rc, out = sh(["python3", PCA, "loop", str(ch), str(sec)], 10)
    elif a == "stop":
        rc, out = sh(["python3", PCA, "stop"], 10)
    elif a == "alloff":
        rc, out = sh(["python3", PCA, "alloff"], 10)
    elif a == "init":
        rc, out = sh(["python3", PCA, "init"], 10)
    else:
        return False, "动作不在白名单"
    return rc == 0, out.strip()[-300:]


def act_panel(which):
    tool = "/home/voice/td7800_spi_tool.sh"
    if not os.path.exists(tool):
        return False, "td7800_spi_tool.sh 不存在"
    if which not in ("lighton", "bist_on", "bist_off", "id"):
        return False, "动作不在白名单"
    rc, out = sh(["sh", tool, which], 15)
    return rc == 0, out.strip()[-300:]


# ── HTTP ──────────────────────────────────────────────────────────────

LAST_JPG = None      # 最后一张完整快照的缓存：vw_cur.jpg 是 cp 出来的，非原子，
                     # 读到半张时退回上一张完整的，避免前端裂图


class H(BaseHTTPRequestHandler):
    server_version = "astra-webctl/1.0"

    def log_message(self, *a):                 # 安静，别刷 journal
        pass

    def _json(self, obj, code=200):
        b = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        # ⚠ self.path 含查询串（/api/snapshot?t=123），路由必须先剥掉——
        # 首版用全等匹配，前端带防缓存参数后 100% 404，快照永远裂图
        path = self.path.split("?", 1)[0]
        if path in ("/", "/index.html"):
            try:
                b = open(INDEX, "rb").read()
            except OSError:
                self.send_error(404); return
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(b)))
            self.end_headers()
            self.wfile.write(b)
        elif path == "/api/status":
            self._json(collect_status())
        elif path == "/api/snapshot":
            global LAST_JPG
            try:
                b = open("/tmp/vw_cur.jpg", "rb").read()
            except OSError:
                b = None
            # 完整性校验：JPEG 头 FFD8 + 尾 FFD9（cp 非原子，半张就退回缓存）
            if b and len(b) > 2000 and b[:2] == b"\xff\xd8" and b[-2:] == b"\xff\xd9":
                LAST_JPG = b
            if not LAST_JPG:
                self.send_error(404); return
            self.send_response(200)
            self.send_header("Content-Type", "image/jpeg")
            self.send_header("Content-Length", str(len(LAST_JPG)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(LAST_JPG)
        else:
            self.send_error(404)

    def do_POST(self):
        n = int(self.headers.get("Content-Length") or 0)
        try:
            body = json.loads(self.rfile.read(n) or b"{}")
        except Exception:
            self._json({"ok": False, "msg": "bad json"}, 400); return

        route = {
            "/api/service": lambda: act_service(body.get("name", ""), body.get("action", "")),
            "/api/volume":  lambda: act_volume(body.get("value", 90)),
            "/api/mic":     lambda: act_mic(body.get("value", 50)),
            "/api/say":     lambda: act_say(body.get("text", "")),
            "/api/wake":    lambda: act_wake(),
            "/api/servo":   lambda: act_servo(body),
            "/api/panel":   lambda: act_panel(body.get("which", "")),
        }.get(self.path)
        if not route:
            self._json({"ok": False, "msg": "no such api"}, 404); return
        try:
            ok, msg = route()
        except Exception as e:
            ok, msg = False, "内部错误: %s" % e
        self._json({"ok": ok, "msg": msg})


if __name__ == "__main__":
    srv = ThreadingHTTPServer(("0.0.0.0", PORT), H)
    print("astra-webctl 监听 :%d  (setvol=%s pca=%s)" % (PORT, SETVOL, PCA))
    srv.serve_forever()
