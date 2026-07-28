#!/bin/sh
python3 - <<'EOF'
import struct, ctypes, os
libc = ctypes.CDLL(None, use_errno=True)
def ioctl(fd, req, buf):
    r = libc.ioctl(fd, ctypes.c_ulong(req), buf)
    if r < 0: raise OSError(ctypes.get_errno(), "ioctl")
    return r
fd = os.open("/dev/spidev0.0", os.O_RDWR)
ioctl(fd, 0x40016b01, ctypes.byref(ctypes.c_uint8(0)))
ioctl(fd, 0x40016b03, ctypes.byref(ctypes.c_uint8(9)))
ioctl(fd, 0x40046b04, ctypes.byref(ctypes.c_uint32(500000)))
tx_words = [0x155, 0x0AA, 0x1FF, 0x000, 0x123, 0x0BF]
n = len(tx_words) * 2
tx = ctypes.create_string_buffer(b"".join(struct.pack("<H", w) for w in tx_words), n)
rx = ctypes.create_string_buffer(n)
t = struct.pack("QQIIHBBBBH", ctypes.addressof(tx), ctypes.addressof(rx), n, 500000, 0, 9, 0, 0, 0, 0)
ioctl(fd, 0x40206b00, ctypes.create_string_buffer(t, len(t)))
rxw = [struct.unpack_from("<H", rx.raw, i*2)[0] & 0x1FF for i in range(len(tx_words))]
print("TX:", " ".join("%03X" % w for w in tx_words))
print("RX:", " ".join("%03X" % w for w in rxw))
print("回环判定:", "★ 全通过 — SL1680侧无罪" if rxw == tx_words else "不一致")
os.close(fd)
EOF
