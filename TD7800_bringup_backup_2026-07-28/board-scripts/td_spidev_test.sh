#!/bin/sh
echo "=== 0. 加载 spidev / 触摸探针 ==="
modprobe spidev 2>/dev/null
ls -l /dev/spidev* 2>/dev/null || echo "无 /dev/spidev 节点!"
i2cdetect -y -r 0 2>/dev/null | grep "^20:"
echo
python3 - <<'EOF'
import fcntl, struct, ctypes, os, sys

DEV = None
for cand in ("/dev/spidev0.0", "/dev/spidev1.0", "/dev/spidev32766.0"):
    if os.path.exists(cand):
        DEV = cand
        break
if not DEV:
    import glob
    g = glob.glob("/dev/spidev*")
    if g: DEV = g[0]
if not DEV:
    print("没有 spidev 设备"); sys.exit(1)
print("使用", DEV)

SPI_IOC_WR_MODE = 0x40016b01
SPI_IOC_WR_BITS_PER_WORD = 0x40016b03
SPI_IOC_WR_MAX_SPEED_HZ = 0x40046b04
SPI_IOC_MESSAGE_1 = 0x40206b00

def xfer(fd, words):
    n = len(words) * 2
    tx = ctypes.create_string_buffer(b"".join(struct.pack("<H", w) for w in words), n)
    rx = ctypes.create_string_buffer(n)
    t = struct.pack("QQIIHBBBBH", ctypes.addressof(tx), ctypes.addressof(rx),
                    n, 500000, 0, 9, 0, 0, 0, 0)
    fcntl.ioctl(fd, SPI_IOC_MESSAGE_1, t)
    return [struct.unpack_from("<H", rx.raw, i * 2)[0] & 0x1FF for i in range(len(words))]

def run(mode):
    fd = os.open(DEV, os.O_RDWR)
    fcntl.ioctl(fd, SPI_IOC_WR_MODE, struct.pack("B", mode))
    fcntl.ioctl(fd, SPI_IOC_WR_BITS_PER_WORD, struct.pack("B", 9))
    fcntl.ioctl(fd, SPI_IOC_WR_MAX_SPEED_HZ, struct.pack("I", 500000))
    xfer(fd, [0x038])                      # enter read mode
    rx = xfer(fd, [0x0BF] + [0x000] * 14)  # read cmd + 14 dummy, CS 全程低
    xfer(fd, [0x039])                      # exit read mode
    print("mode%d RX(9bit词): %s" % (mode, " ".join("%03X" % w for w in rx)))
    bs = "".join(format(w, "09b") for w in rx)
    sig = [0x02, 0x3C, 0x68, 0x0A]
    hit = None
    for stride in (9, 8):
        for off in range(0, len(bs) - stride * 4):
            vals = []
            k = off
            while k + stride <= len(bs) and len(vals) < 8:
                vals.append(int(bs[k:k + stride][-8:], 2)); k += stride
            for i in range(len(vals) - 3):
                if vals[i:i + 4] == sig:
                    hit = (stride, off, vals)
                    break
            if hit: break
        if hit: break
    if hit:
        print("★★ 命中器件码 02 3C 68 0A (stride=%d off=%d) —— IC 活着, SPI 通!" % hit[:2])
    os.close(fd)
    return fd, hit is not None

ok = False
for m in (0, 3):
    try:
        _, ok = run(m)
    except Exception as e:
        print("mode%d 异常: %s" % (m, e))
    if ok:
        break

print()
print("=== BIST: B0<-00, D6<-00, DE<-01 (mode0) ===")
fd = os.open(DEV, os.O_RDWR)
fcntl.ioctl(fd, SPI_IOC_WR_MODE, struct.pack("B", 0))
fcntl.ioctl(fd, SPI_IOC_WR_BITS_PER_WORD, struct.pack("B", 9))
fcntl.ioctl(fd, SPI_IOC_WR_MAX_SPEED_HZ, struct.pack("I", 500000))
for c, p in ((0xB0, 0x00), (0xD6, 0x00), (0xDE, 0x01)):
    xfer(fd, [c, 0x100 | p])
    print("  写 %02X <- %02X" % (c, p))
os.close(fd)
print("★★ BIST 已发送 —— 看屏!")
print("ID判定:", "通过" if ok else "未命中(看RX原始词)")
EOF
