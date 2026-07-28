#!/bin/sh
python3 - <<'EOF'
import struct, ctypes, os, time
libc = ctypes.CDLL(None, use_errno=True)
def ioctl(fd, req, buf):
    r = libc.ioctl(fd, ctypes.c_ulong(req), buf)
    if r < 0: raise OSError(ctypes.get_errno(), "ioctl")
fd = os.open("/dev/spidev0.0", os.O_RDWR)
ioctl(fd, 0x40016b01, ctypes.byref(ctypes.c_uint8(0)))
ioctl(fd, 0x40016b03, ctypes.byref(ctypes.c_uint8(9)))
ioctl(fd, 0x40046b04, ctypes.byref(ctypes.c_uint32(500000)))
def cmd(c):
    tx = ctypes.create_string_buffer(struct.pack("<H", c), 2)
    rx = ctypes.create_string_buffer(2)
    t = struct.pack("QQIIHBBBBH", ctypes.addressof(tx), ctypes.addressof(rx), 2, 500000, 0, 9, 0, 0, 0, 0)
    ioctl(fd, 0x40206b00, ctypes.create_string_buffer(t, len(t)))
print("送 29h (Display On)")
cmd(0x029)
time.sleep(0.2)
print("送 11h (Sleep Out)")
cmd(0x011)
time.sleep(0.15)
os.close(fd)
print("完成 —— 看屏!")
EOF
