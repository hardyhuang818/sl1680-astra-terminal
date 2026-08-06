#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""PCA9685 16 路舵机驱动 —— SL1680 用户态版（走 /dev/i2c-N，不需要内核驱动）

为什么走用户态：
  板子内核 CONFIG_PWM_PCA9685 未开（源码在，可以编成模块，但要重编+烧录+重启，
  而这块板的软复位不可靠，每次都要人工断电）。CONFIG_I2C_CHARDEV=y 已经有了，
  所以用户态直接写寄存器最省事，先把舵机转起来再说。

接线（详见 PCA9685_MG90S_接入SL1680_2026-07-31.md）：
  PCA9685 VCC -> J32.1 或 J32.17 (3.3V)    ★ 不要接 5V，会把 5V 灌到 TXB0108 的 3.3V 侧
  PCA9685 GND -> J32 任意 GND
  PCA9685 SDA -> J32.3  (TW0_SDA, 已过电平转换=3.3V 域)
  PCA9685 SCL -> J32.5  (TW0_SCL, 同上)
  PCA9685 V+  -> 外部 5~6V 电源正极        ★ 绝不能从板子取
  外部电源 GND -> 与板子共地

板上 python3 没有 fcntl / smbus，所以用 ctypes 直调 libc 的 ioctl。

地址是自动找的，不用手写：
  本板 0x40/0x41 被两颗板载 INA3221 电流监测芯片占了（base DTS 里声明的），
  所以 PCA9685 的出厂默认地址用不了。脚本会依次探测 0x40~0x47，
  找不到就退回 PCA9685 的 All Call 广播地址 0x70（ALLCALL 位默认开启，一定能用）。
  想强制指定：  PCA_ADDR=0x42 python3 pca9685.py init

用法:
  python3 pca9685.py scan                 扫描 i2c 总线，确认芯片在不在
  python3 pca9685.py init [freq]          初始化（默认 50Hz，MG90S 标准）
  python3 pca9685.py angle <ch> <deg>     0~180 度（全速）
  python3 pca9685.py move <ch> <deg> [°/s] 匀速走到目标角度（默认 60°/s，软件渐移）
  python3 pca9685.py us <ch> <微秒>       直接给脉宽（500~2500）
  python3 pca9685.py sweep <ch> [次数]    来回扫，验收用
  python3 pca9685.py loop <ch> [秒数]     后台持续来回摆（演示用，默认 180 秒）
  python3 pca9685.py stop                 停掉后台 loop 并松力（板上没有 pkill）
  python3 pca9685.py speed <ch> <-100~100> 360度舵机：转速与方向
  python3 pca9685.py off <ch>             单通道停止输出（舵机松力）
  python3 pca9685.py alloff               全部停止
"""

import ctypes, os, struct, sys, time

# ── 可调 ──────────────────────────────────────────────────────────────
BUS      = int(os.environ.get("PCA_BUS", "0"))     # i2c-0 = TW0 = J32.3/5
ADDR     = None                                    # 自动探测，见 find_addr()
ALLCALL  = 0x70                                    # PCA9685 广播地址(0xE0>>1)，兜底
LOOPFILE = "/tmp/pca_loop_run.sh"
VERBOSE_ADDR = False                               # 只有 init/scan 打地址提示，见 __main__
FREQ     = 50                                       # Hz，MG90S 标准 20ms 周期
US_MIN   = 500     # 0 度   —— 见 MG90S/使用说明.txt
US_MAX   = 2500    # 180 度
OSC_HZ   = 25_000_000   # PCA9685 内部振荡器标称 25MHz
# ─────────────────────────────────────────────────────────────────────

# 寄存器
MODE1, MODE2      = 0x00, 0x01
LED0_ON_L         = 0x06
ALL_LED_ON_L      = 0xFA
PRESCALE          = 0xFE
# MODE1 位
M1_RESTART, M1_EXTCLK, M1_AI, M1_SLEEP, M1_ALLCALL = 0x80, 0x40, 0x20, 0x10, 0x01
# MODE2 位
M2_OUTDRV = 0x04   # 图腾柱输出（舵机要这个，不是开漏）

I2C_SLAVE = 0x0703
_libc = ctypes.CDLL(None, use_errno=True)


class I2C:
    def __init__(self, bus, addr):
        path = "/dev/i2c-%d" % bus
        if not os.path.exists(path):
            die("%s 不存在。检查 CONFIG_I2C_CHARDEV 或总线号（PCA_BUS 环境变量可改）" % path)
        self.fd = os.open(path, os.O_RDWR)
        if _libc.ioctl(self.fd, ctypes.c_ulong(I2C_SLAVE), ctypes.c_ulong(addr)) < 0:
            e = ctypes.get_errno()
            os.close(self.fd)
            die("绑定从机地址 0x%02X 失败: errno=%d (%s)\n"
                "  16 = EBUSY，说明该地址已被内核驱动占用（触摸在 0x2c，别撞）" %
                (addr, e, os.strerror(e)))

    def wr(self, reg, *data):
        os.write(self.fd, bytes([reg & 0xFF] + [d & 0xFF for d in data]))

    def rd(self, reg, n=1):
        os.write(self.fd, bytes([reg & 0xFF]))
        return os.read(self.fd, n)

    def close(self):
        os.close(self.fd)


def die(msg, code=1):
    sys.stderr.write("错误: %s\n" % msg)
    sys.exit(code)


def _try_addr(addr):
    """能绑上并读出像 PCA9685 的寄存器就返回 True。
    被内核驱动占用的地址会在 ioctl 阶段 EBUSY，自然跳过（本板 0x40/0x41 是 INA3221）。"""
    path = "/dev/i2c-%d" % BUS
    try:
        fd = os.open(path, os.O_RDWR)
    except OSError:
        return False
    try:
        if _libc.ioctl(fd, ctypes.c_ulong(I2C_SLAVE), ctypes.c_ulong(addr)) < 0:
            return False
        os.write(fd, bytes([PRESCALE]))
        pre = os.read(fd, 1)[0]
        os.write(fd, bytes([MODE1]))
        m1 = os.read(fd, 1)[0]
        # PCA9685: PRE_SCALE 合法范围 3~255；MODE1 的 bit1 是保留位，恒 0
        return 3 <= pre <= 255 and not (m1 & 0x02)
    except OSError:
        return False
    finally:
        os.close(fd)


def find_addr(quiet=None):
    """定地址：环境变量 > 探测 0x40~0x47 > All Call 0x70

    quiet=None 时按 VERBOSE_ADDR 决定要不要打提示 —— 只有 init/scan 会打，
    angle/us/sweep 这类高频命令保持安静，否则每敲一次都刷一行很吵。"""
    global ADDR
    if quiet is None:
        quiet = not VERBOSE_ADDR
    if ADDR is not None:
        return ADDR
    env = os.environ.get("PCA_ADDR")
    if env:
        ADDR = int(env, 0)
        return ADDR
    for a in range(0x40, 0x48):
        if _try_addr(a):
            ADDR = a
            if not quiet:
                print("(自动识别到 PCA9685 @ 0x%02X)" % a)
            return ADDR
    if _try_addr(ALLCALL):
        ADDR = ALLCALL
        if not quiet:
            print("(0x40~0x47 都不可用 —— 本板 0x40/0x41 被 INA3221 占着；"
                  "退回 All Call 广播地址 0x70。功能不受影响；"
                  "短接模块 A1 焊点可得到独立地址 0x42)")
        return ADDR
    die("找不到 PCA9685。先跑 `python3 %s scan` 看总线上有什么；\n"
        "  也可以 i2cdetect -y -r %d 交叉验证（芯片在线时 0x70 会出现）" %
        (os.path.basename(sys.argv[0]), BUS))


def dev():
    return I2C(BUS, find_addr())


def counts_per_us():
    """一个 4096 分度对应多少微秒（按实际 prescale 反算，不用标称值）"""
    return 1_000_000.0 / FREQ / 4096.0


def us_to_counts(us):
    c = int(round(us / counts_per_us()))
    return max(0, min(4095, c))


# ── 操作 ──────────────────────────────────────────────────────────────

def op_scan():
    print("扫描 /dev/i2c-%d ..." % BUS)
    path = "/dev/i2c-%d" % BUS
    if not os.path.exists(path):
        die("%s 不存在" % path)
    found = []
    for a in range(0x03, 0x78):
        try:
            fd = os.open(path, os.O_RDWR)
        except OSError as e:
            die("打开 %s 失败: %s" % (path, e))
        try:
            if _libc.ioctl(fd, ctypes.c_ulong(I2C_SLAVE), ctypes.c_ulong(a)) < 0:
                continue          # EBUSY = 被内核驱动占着，也算"有东西"
            try:
                os.read(fd, 1)
                found.append(a)
            except OSError:
                pass
        finally:
            os.close(fd)
    print("  应答的地址:", " ".join("0x%02X" % a for a in found) if found else "(无)")
    hit = [a for a in found if 0x40 <= a <= 0x47]
    if hit:
        print("  ★ PCA9685 在 0x%02X（独立地址，最理想）" % hit[0])
    elif ALLCALL in found:
        print("  ★ PCA9685 在线 —— 通过 All Call 广播地址 0x70 应答")
        print("    它的出厂地址 0x40 被板载 INA3221 占着（0x40/0x41 两颗）。")
        print("    照常能用；想要独立地址就把模块上的 A1 焊点短接 -> 0x42。")
    else:
        print("  ✗ 没找到 PCA9685。检查：VCC(3.3V)/GND 是否接好、SDA/SCL 有没有插反、")
        print("    以及 i2cdetect -y -r %d 的结果（芯片在线时 0x70 一定会出现）" % BUS)
    print("  提示: 触摸屏 TDDI 在 0x2c、INA3221 在 0x40/0x41，")
    print("        它们被内核驱动占用，i2cdetect 显示 UU，本脚本会自动跳过")


def op_init(freq=None):
    global FREQ
    if freq:
        FREQ = int(freq)
    d = dev()
    try:
        # 1) 先睡下去才能改 PRE_SCALE（datasheet 7.3.5）
        old = d.rd(MODE1)[0]
        d.wr(MODE1, (old & ~M1_RESTART) | M1_SLEEP)

        # 2) prescale = round(osc / (4096 * freq)) - 1
        pre = int(round(OSC_HZ / (4096.0 * FREQ))) - 1
        pre = max(3, min(255, pre))
        d.wr(PRESCALE, pre)

        # 3) 醒过来，开自动地址递增
        d.wr(MODE1, (old & ~M1_SLEEP) | M1_AI)
        time.sleep(0.001)                       # 振荡器起振需要 >500us
        d.wr(MODE1, (old & ~M1_SLEEP) | M1_AI | M1_RESTART)

        # 4) 图腾柱输出（舵机信号线要推挽，不能开漏）
        d.wr(MODE2, M2_OUTDRV)

        actual = OSC_HZ / (4096.0 * (pre + 1))
        print("初始化完成")
        print("  地址      0x%02X  (i2c-%d)" % (ADDR, BUS))
        print("  目标频率  %d Hz  ->  PRE_SCALE=%d  ->  实际 %.2f Hz (周期 %.2f ms)"
              % (FREQ, pre, actual, 1000.0 / actual))
        print("  MODE1=0x%02X  MODE2=0x%02X" % (d.rd(MODE1)[0], d.rd(MODE2)[0]))
        print("  分度         1 count = %.2f us" % (1_000_000.0 / actual / 4096.0))
        print("  舵机行程     %d~%d us  ->  count %d~%d"
              % (US_MIN, US_MAX, us_to_counts(US_MIN), us_to_counts(US_MAX)))
    finally:
        d.close()


def _swrst():
    """I2C General-Call (0x00) 发 0x06 = PCA9685 软件复位。
    这是清掉粘滞位 EXTCLK 的唯一软件手段（datasheet 7.6：EXTCLK 一旦置 1，
    只有断电或 SWRST 能清）。EXTCLK=1 且引脚无时钟时，振荡器停转 →
    SLEEP 怎么写都清不掉、PWM 永远不输出 —— 2026-08-05 实测中招。"""
    fd = os.open("/dev/i2c-%d" % BUS, os.O_RDWR)
    try:
        # I2C_SLAVE 对地址 0 会拒，用 I2C_SLAVE_FORCE(0x0706)
        if _libc.ioctl(fd, ctypes.c_ulong(0x0706), ctypes.c_ulong(0x00)) < 0:
            raise OSError(ctypes.get_errno(), "bind general-call")
        os.write(fd, bytes([0x06]))
    finally:
        os.close(fd)
    time.sleep(0.01)


def _ensure_awake(d):
    """PCA9685 断电重启后默认 SLEEP（寄存器能写但 PWM 不输出）；
    另见 _swrst 的 EXTCLK 粘滞位问题。写输出前自动恢复到能出波的状态。"""
    m1 = d.rd(MODE1)[0]
    if m1 & M1_EXTCLK:
        sys.stderr.write("(MODE1=0x%02X 含粘滞位 EXTCLK，先 SWRST 软件复位)\n" % m1)
        _swrst()
        m1 = d.rd(MODE1)[0]                 # 复位后应为 0x11
    if not (m1 & M1_SLEEP):
        return
    pre = max(3, min(255, int(round(OSC_HZ / (4096.0 * FREQ))) - 1))
    base = m1 & ~(M1_RESTART | M1_EXTCLK)   # 绝不把 EXTCLK 写回去
    d.wr(MODE1, base | M1_SLEEP)
    d.wr(PRESCALE, pre)
    d.wr(MODE1, (base & ~M1_SLEEP) | M1_AI)
    time.sleep(0.001)                       # 振荡器起振 >500us
    d.wr(MODE1, (base & ~M1_SLEEP) | M1_AI | M1_RESTART)
    d.wr(MODE2, M2_OUTDRV)
    m1 = d.rd(MODE1)[0]
    sys.stderr.write("(自动初始化 %dHz, MODE1=0x%02X%s)\n" % (
        FREQ, m1, "" if not (m1 & M1_SLEEP) else " ⚠ 仍在SLEEP, 检查接线/供电"))


def _set_counts(d, ch, on, off):
    if not 0 <= ch <= 15:
        die("通道号必须是 0~15")
    _ensure_awake(d)
    base = LED0_ON_L + 4 * ch
    d.wr(base, on & 0xFF, (on >> 8) & 0x0F, off & 0xFF, (off >> 8) & 0x0F)


def op_us(ch, us):
    us = float(us)
    if not 300 <= us <= 2700:
        die("脉宽 %g us 超出安全范围 300~2700（MG90S 标称 500~2500，超了会顶死堵转）" % us)
    d = dev()
    try:
        c = us_to_counts(us)
        _set_counts(d, ch, 0, c)
        print("CH%-2d  %.0f us  ->  count %d  (约 %.1f 度)"
              % (ch, us, c, (us - US_MIN) * 180.0 / (US_MAX - US_MIN)))
    finally:
        d.close()


def op_angle(ch, deg):
    deg = float(deg)
    if not 0 <= deg <= 180:
        die("角度必须 0~180")
    us = US_MIN + (US_MAX - US_MIN) * deg / 180.0
    op_us(ch, us)


def _read_angle(d, ch):
    """从 OFF 寄存器回读当前命令角度；没输出过(全关/0)返回 None"""
    base = LED0_ON_L + 4 * ch
    raw = d.rd(base, 4)
    if (raw[3] >> 4) & 1:                      # 全关位
        return None
    off = raw[2] | ((raw[3] & 0x0F) << 8)
    if off == 0:
        return None
    us = off * (1_000_000.0 / FREQ / 4096.0)
    return (us - US_MIN) * 180.0 / (US_MAX - US_MIN)


def op_move(ch, deg, dps=60):
    """匀速走到目标角度（软件渐移）。

    180° 位置舵机(MG90S 标准版)硬件上没有转速控制——脉宽只命令位置，舵机全速去。
    这里把行程拆成 25ms 一步的小步进，得到可控的角速度。
    360° 连续旋转版不要用这个，用 speed。"""
    deg = max(0.0, min(180.0, float(deg)))
    dps = max(5.0, min(360.0, float(dps)))
    d = dev()
    try:
        _ensure_awake(d)
        cur = _read_angle(d, ch)
        if cur is None:
            cur = 90.0                          # 没有已知位置就从中位算起
        step = dps * 0.025                      # 每 25ms 走多少度
        n = max(1, int(abs(deg - cur) / step))
        sgn = 1.0 if deg >= cur else -1.0
        for i in range(1, n + 1):
            a = cur + sgn * step * i
            a = min(deg, a) if sgn > 0 else max(deg, a)
            us = US_MIN + (US_MAX - US_MIN) * a / 180.0
            _set_counts(d, ch, 0, us_to_counts(us))
            time.sleep(0.025)
        us = US_MIN + (US_MAX - US_MIN) * deg / 180.0
        _set_counts(d, ch, 0, us_to_counts(us))
        print("CH%d  %.0f° -> %.0f°  @%.0f°/s  (%.1fs)"
              % (ch, cur, deg, dps, abs(deg - cur) / dps))
    finally:
        d.close()


def op_speed(ch, pct):
    """360 度连续旋转舵机：-100=反向最大, 0=停, +100=正向最大"""
    pct = float(pct)
    if not -100 <= pct <= 100:
        die("速度必须 -100~100")
    # 使用说明：0.5ms 正向最大 / 1.5ms 停 / 2.5ms 反向最大
    us = 1500 - pct * 10.0
    op_us(ch, us)


def op_sweep(ch, times=3):
    d = dev()
    try:
        print("CH%d 来回扫 %d 次 (Ctrl-C 中止)" % (ch, int(times)))
        for n in range(int(times)):
            for deg in list(range(0, 181, 5)) + list(range(180, -1, -5)):
                us = US_MIN + (US_MAX - US_MIN) * deg / 180.0
                _set_counts(d, ch, 0, us_to_counts(us))
                time.sleep(0.02)
            print("  第 %d 趟完成" % (n + 1))
        _set_counts(d, ch, 0, us_to_counts(1500))   # 回中
        print("  已回中 (1500us)")
    except KeyboardInterrupt:
        print("\n  中止")
    finally:
        d.close()


def op_off(ch):
    d = dev()
    try:
        if not 0 <= ch <= 15:
            die("通道号必须是 0~15")
        # OFF 寄存器 bit12 = 全关，输出恒低，舵机失去保持力矩
        base = LED0_ON_L + 4 * ch
        d.wr(base, 0, 0, 0, 0x10)
        print("CH%d 已停止输出（舵机松力）" % ch)
    finally:
        d.close()


def op_alloff():
    d = dev()
    try:
        d.wr(ALL_LED_ON_L, 0, 0, 0, 0x10)
        print("全部 16 路已停止输出")
    finally:
        d.close()


def _loop_pids():
    """板上 busybox 没有 pkill，只能自己从 ps 里挑，并排除自己这个进程"""
    me = os.getpid()
    pids = []
    try:
        out = os.popen("ps 2>/dev/null").read()
    except Exception:
        return pids
    for ln in out.splitlines():
        if "pca_loop_run" not in ln:
            continue
        f = ln.split()
        if not f or not f[0].isdigit():
            continue
        p = int(f[0])
        if p != me:
            pids.append(p)
    return pids


def op_loop(ch, secs=180):
    """后台持续来回摆，演示/找问题时不用一直守着终端"""
    secs = int(secs)
    a = find_addr()
    op_stop(quiet=True)
    script = (
        "#!/bin/sh\n"
        "END=$(( $(cut -d. -f1 /proc/uptime) + %d ))\n"
        "while [ \"$(cut -d. -f1 /proc/uptime)\" -lt \"$END\" ]; do\n"
        "  PCA_ADDR=0x%02X python3 %s angle %d 0   >/dev/null 2>&1; sleep 1\n"
        "  PCA_ADDR=0x%02X python3 %s angle %d 180 >/dev/null 2>&1; sleep 1\n"
        "done\n"
        "PCA_ADDR=0x%02X python3 %s angle %d 90 >/dev/null 2>&1\n"
        % (secs, a, os.path.abspath(sys.argv[0]), ch,
           a, os.path.abspath(sys.argv[0]), ch,
           a, os.path.abspath(sys.argv[0]), ch))
    with open(LOOPFILE, "w") as f:
        f.write(script)
    os.chmod(LOOPFILE, 0o755)
    os.system("nohup sh %s >/dev/null 2>&1 &" % LOOPFILE)
    time.sleep(1)
    print("CH%d 开始后台来回摆，持续 %d 秒" % (ch, secs))
    print("  停止：python3 %s stop" % os.path.basename(sys.argv[0]))


def op_stop(quiet=False):
    pids = _loop_pids()
    for p in pids:
        try:
            os.kill(p, 9)
        except OSError:
            pass
    if not quiet:
        print("已停掉 %d 个后台 loop" % len(pids) if pids else "没有在跑的后台 loop")
    time.sleep(0.3)
    try:
        os.remove(LOOPFILE)
    except OSError:
        pass
    if not quiet:
        op_alloff()


USAGE = __doc__.split("用法:")[1].strip()

if __name__ == "__main__":
    a = sys.argv[1:]
    if not a:
        print("用法:\n  " + USAGE.replace("\n", "\n  "))
        sys.exit(0)
    cmd = a[0]
    VERBOSE_ADDR = cmd in ("init", "scan")   # 其余命令安静，不每次都刷地址提示
    try:
        if   cmd == "scan":   op_scan()
        elif cmd == "init":   op_init(a[1] if len(a) > 1 else None)
        elif cmd == "angle":  op_angle(int(a[1]), a[2])
        elif cmd == "move":   op_move(int(a[1]), a[2], a[3] if len(a) > 3 else 60)
        elif cmd == "us":     op_us(int(a[1]), a[2])
        elif cmd == "speed":  op_speed(int(a[1]), a[2])
        elif cmd == "sweep":  op_sweep(int(a[1]), a[2] if len(a) > 2 else 3)
        elif cmd == "loop":   op_loop(int(a[1]), a[2] if len(a) > 2 else 180)
        elif cmd == "stop":   op_stop()
        elif cmd == "off":    op_off(int(a[1]))
        elif cmd == "alloff": op_alloff()
        else:
            die("未知命令 '%s'\n用法:\n  %s" % (cmd, USAGE.replace("\n", "\n  ")))
    except IndexError:
        die("参数不足\n用法:\n  %s" % USAGE.replace("\n", "\n  "))
