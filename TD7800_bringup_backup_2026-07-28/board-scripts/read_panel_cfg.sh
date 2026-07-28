#!/bin/sh
python3 - <<'EOF'
import struct, ctypes, os
libc = ctypes.CDLL(None, use_errno=True)
def ioctl(fd, req, buf):
    r = libc.ioctl(fd, ctypes.c_ulong(req), buf)
    if r < 0: raise OSError(ctypes.get_errno(), "ioctl")
fd = os.open("/dev/spidev0.0", os.O_RDWR)
ioctl(fd, 0x40016b01, ctypes.byref(ctypes.c_uint8(0)))
ioctl(fd, 0x40016b03, ctypes.byref(ctypes.c_uint8(9)))
ioctl(fd, 0x40046b04, ctypes.byref(ctypes.c_uint32(500000)))
def xfer(words):
    n = len(words) * 2
    tx = ctypes.create_string_buffer(b"".join(struct.pack("<H", w) for w in words), n)
    rx = ctypes.create_string_buffer(n)
    t = struct.pack("QQIIHBBBBH", ctypes.addressof(tx), ctypes.addressof(rx), n, 500000, 0, 9, 0, 0, 0, 0)
    ioctl(fd, 0x40206b00, ctypes.create_string_buffer(t, len(t)))
    return [struct.unpack_from("<H", rx.raw, i*2)[0] & 0x1FF for i in range(len(words))]

def read_reg(cmd, nparams):
    xfer([0x038])
    rx = xfer([cmd] + [0x000] * (nparams + 3))
    xfer([0x039])
    bs = "".join(format(w, "09b") for w in rx)
    # 锚定: 找命令回显(任意位偏移, stride=8), 后续字节即参数
    for off in range(0, 18):
        if off + 8 > len(bs): break
        if int(bs[off:off+8], 2) == cmd:
            params = []
            k = off + 8
            while k + 8 <= len(bs) and len(params) < nparams:
                params.append(int(bs[k:k+8], 2)); k += 8
            return params, off, bs
    return None, -1, bs

print("=== BFh 器件码 (校准读通路) ===")
p, off, bs = read_reg(0xBF, 5)
print("params:", " ".join("%02X" % v for v in p) if p else "锚定失败 raw=" + bs[:60])

print()
print("=== B1h LVDS IF Setting (面板真实配置) ===")
p, off, bs = read_reg(0xB1, 7)
if p:
    print("params:", " ".join("%02X" % v for v in p))
    p1 = p[0]
    lvfmt = (p1 >> 3) & 1
    lvcolmod = (p1 >> 2) & 1
    lvsynm = p1 & 3
    print("  LVFMT   =", lvfmt, "(0=VESA, 1=JEIDA)")
    print("  LVCOLMOD=", lvcolmod, "(0=18bit3lane, 1=24bit4lane)")
    print("  LVSYNM  =", lvsynm, "(0=VS+HS, 1=DE, 2/3=VS+HS+DE)")
    print("  LVHBP   =", ((p[1] & 0xF) << 8) | p[2], "LVDS clks")
    print("  LVHFP   =", ((p[3] & 0xF) << 8) | p[4], "LVDS clks")
    print("  LVVBP   =", ((p[5] & 0xF) << 8) | p[6], "行")
else:
    print("锚定失败 raw=" + bs[:80])

print()
print("=== C0h Display Timing (面板原生时序) ===")
p, off, bs = read_reg(0xC0, 7)
if p:
    print("params:", " ".join("%02X" % v for v in p))
    rtn = ((p[0] & 0xF) << 8) | p[1]
    vbp = p[2]
    nl = ((p[3] & 0xF) << 8) | p[4]
    vfp = (p[5] << 8) | p[6]
    print("  RTN(1H周期) =", rtn, "RCLKs")
    print("  VBP =", vbp, "行")
    print("  NL(垂直有效行数) =", nl, "  ← 期望 720!")
    print("  VFP =", vfp, "行")
else:
    print("锚定失败 raw=" + bs[:80])
os.close(fd)
EOF
