#!/bin/sh
echo "=== 1. 关 BIST (DE<-00), 视频源切回 LVDS ==="
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
xfer([0x0B0, 0x100])   # B0 <- 00 解锁
xfer([0x0DE, 0x100])   # DE <- 00 TIGON=0
os.close(fd)
print("DE<-00 已写, 视频源回到 LVDS 输入")
EOF
echo
echo "=== 2. 重启 weston (桥片重新初始化 + 推桌面) ==="
systemctl restart weston
sleep 4
echo "weston: $(systemctl is-active weston)"
echo "DSI-1: $(cat /sys/class/drm/card0-DSI-1/status) $(cat /sys/class/drm/card0-DSI-1/enabled)"
echo
echo "★★ 看屏: 出 Weston 桌面 = LVDS 链路全通!"
