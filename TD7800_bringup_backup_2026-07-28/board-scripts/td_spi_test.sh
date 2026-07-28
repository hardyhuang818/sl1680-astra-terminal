#!/bin/sh
echo "=== 0. 触摸探针: i2c-0 有没有 0x2c ==="
i2cdetect -y -r 0 2>/dev/null | grep "^20:"
echo
python3 - <<'EOF'
import os, time

def wf(p, v):
    try:
        open(p, "w").write(v)
        return True
    except Exception:
        return False

class G:
    def __init__(s, n, d):
        s.n = n
        s.p = "/sys/class/gpio/gpio%d" % n
        if not os.path.isdir(s.p):
            wf("/sys/class/gpio/export", str(n))
            time.sleep(0.05)
        s.ok = os.path.isdir(s.p) and wf(s.p + "/direction", d)
    def set(s, v):
        wf(s.p + "/value", "1" if v else "0")
    def get(s):
        return open(s.p + "/value").read().strip() == "1"

def health(g):
    r = []
    for v in (0, 1, 0, 1):
        g.set(v); time.sleep(0.002); r.append(g.get() == bool(v))
    return all(r)

def mkset(name, nscl, nmosi, ncs, nmiso):
    scl, mosi, cs = G(nscl, "out"), G(nmosi, "out"), G(ncs, "out")
    miso = G(nmiso, "in")
    hs = {"SCL(%d)" % nscl: health(scl), "MOSI(%d)" % nmosi: health(mosi), "CS(%d)" % ncs: health(cs)}
    print("候选集 %s 健康: %s  miso可读:%s" % (name, hs, miso.ok))
    return (scl, mosi, cs, miso, all(hs.values()))

def frame_w(scl, mosi, cs, dcx, byte):
    cs.set(0)
    for b in [dcx] + [(byte >> i) & 1 for i in range(7, -1, -1)]:
        scl.set(0); mosi.set(b); scl.set(1)
    scl.set(0); cs.set(1)

def id_read(scl, mosi, cs, miso):
    frame_w(scl, mosi, cs, 0, 0x38)           # enter read mode
    cs.set(0)
    raw = []
    for b in [0] + [(0xBF >> i) & 1 for i in range(7, -1, -1)]:
        scl.set(0); mosi.set(b); raw.append(1 if miso.get() else 0); scl.set(1)
    for _ in range(14 * 9):                    # dummy clocks, keep sampling
        scl.set(0); mosi.set(0); raw.append(1 if miso.get() else 0); scl.set(1)
    scl.set(0); cs.set(1)
    frame_w(scl, mosi, cs, 0, 0x39)           # exit read mode
    bs = "".join(map(str, raw))
    print("原始位流(%d位): %s" % (len(bs), bs))
    sig = [0x02, 0x3C, 0x68, 0x0A]
    for stride in (9, 8):
        for off in range(0, min(40, len(bs) - stride * 4)):
            vals = []
            for k in range(6):
                s0 = off + k * stride
                if s0 + stride > len(bs): break
                seg = bs[s0:s0 + stride]
                vals.append(int(seg[-8:], 2))
            if len(vals) >= 4 and any(vals[i:i+4] == sig for i in range(len(vals) - 3)):
                print("★ 命中器件码 02 3C 68 0A! stride=%d off=%d vals=%s" % (stride, off, ["%02X" % v for v in vals]))
                return True
    # 没命中也把按9bit切的前12字节打出来看
    by = [int(bs[i:i+9][-8:], 2) for i in range(0, len(bs) - 9, 9)][:14]
    print("按9bit切(低8位): %s" % " ".join("%02X" % v for v in by))
    return False

print("=== 1. 候选集A: SCL=549(J32.22) MOSI=551(J32.31) CS=550(J32.32) MISO=514(J32.18) ===")
A = mkset("A", 549, 551, 550, 514)
use = None
if A[4]:
    use = A
else:
    print("=== A 不健康, 试候选集B: 567/560/559/514 ===")
    B = mkset("B", 567, 560, 559, 514)
    if B[4]:
        use = B

if use:
    scl, mosi, cs, miso, _ = use
    cs.set(1); scl.set(0)
    print("=== 2. 读 0xBF 器件码 (期望 02 3C 68 0A) ===")
    ok = id_read(scl, mosi, cs, miso)
    print("ID 判定:", "通过 ✓ IC活着" if ok else "未命中(看上面位流)")
    print("=== 3. 发 BIST: B0<-00, D6<-00, DE<-01 ===")
    for c, p in ((0xB0, 0x00), (0xD6, 0x00), (0xDE, 0x01)):
        frame_w(scl, mosi, cs, 0, c)
        frame_w(scl, mosi, cs, 1, p)
        print("  写 %02X <- %02X" % (c, p))
    cs.set(1); scl.set(0); mosi.set(0)
    print("★★ BIST 已发送 —— 现在看屏! 有测试图案=面板+芯片全好 ★★")
else:
    print("两套候选都不健康, 需要万用表校准: 量 J32.22/31/32 电平并汇报")
EOF
