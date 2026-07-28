#!/bin/sh
echo "=== pinmux 状态确认 ==="
devmem 0xf7fe2c14
echo "=== 触摸探针 ==="
i2cdetect -y -r 0 2>/dev/null | grep "^20:"
echo
sh /dev/stdin <<'OUTER'
exit 0
OUTER
python3 - <<'EOF'
import struct, ctypes, os, sys
libc = ctypes.CDLL(None, use_errno=True)
def ioctl(fd, req, buf):
    r = libc.ioctl(fd, ctypes.c_ulong(req), buf)
    if r < 0: raise OSError(ctypes.get_errno(), "ioctl")
    return r
def setup(fd, mode):
    ioctl(fd, 0x40016b01, ctypes.byref(ctypes.c_uint8(mode)))
    ioctl(fd, 0x40016b03, ctypes.byref(ctypes.c_uint8(9)))
    ioctl(fd, 0x40046b04, ctypes.byref(ctypes.c_uint32(500000)))
def xfer(fd, words):
    n = len(words) * 2
    tx = ctypes.create_string_buffer(b"".join(struct.pack("<H", w) for w in words), n)
    rx = ctypes.create_string_buffer(n)
    t = struct.pack("QQIIHBBBBH", ctypes.addressof(tx), ctypes.addressof(rx), n, 500000, 0, 9, 0, 0, 0, 0)
    ioctl(fd, 0x40206b00, ctypes.create_string_buffer(t, len(t)))
    return [struct.unpack_from("<H", rx.raw, i*2)[0] & 0x1FF for i in range(len(words))]

def id_read(mode):
    fd = os.open("/dev/spidev0.0", os.O_RDWR)
    setup(fd, mode)
    xfer(fd, [0x038])
    rx = xfer(fd, [0x0BF] + [0x000] * 14)
    xfer(fd, [0x039])
    os.close(fd)
    print("mode%d RX: %s" % (mode, " ".join("%03X" % w for w in rx)))
    bs = "".join(format(w, "09b") for w in rx)
    sig = [0x02, 0x3C, 0x68, 0x0A]
    for stride in (9, 8):
        for off in range(0, len(bs) - stride * 4):
            vals = []
            k = off
            while k + stride <= len(bs) and len(vals) < 8:
                vals.append(int(bs[k:k + stride][-8:], 2)); k += stride
            for i in range(len(vals) - 3):
                if vals[i:i + 4] == sig:
                    print("★★ 命中器件码 02 3C 68 0A (stride=%d off=%d)! IC 活了!" % (stride, off))
                    return True
    return False

ok = False
for m in (0, 3):
    try:
        ok = id_read(m)
    except Exception as e:
        print("mode%d 异常:" % m, e)
    if ok: break

print()
print("=== BIST ===")
fd = os.open("/dev/spidev0.0", os.O_RDWR)
setup(fd, 0)
for c, p in ((0xB0, 0x00), (0xD6, 0x00), (0xDE, 0x01)):
    xfer(fd, [c, 0x100 | p])
    print("  写 %02X <- %02X" % (c, p))
os.close(fd)
print("★★ BIST 已发 —— 看屏!")
print("ID 判定:", "通过" if ok else "未命中")
EOF
