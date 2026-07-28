#!/bin/sh
# TD7800 显示 SPI 工具（SL1680 侧）
#   id       读 0xBF 器件码（期望 02 3C 68 0A）
#   bist_on  开测试图案（B0<-00, D6<-00, DE<-01）
#   bist_off 关测试图案（DE<-00，视频源回 LVDS）
#   lighton  发 29h Display-On + 11h Sleep-Out（厂商 initial code 收尾序）
#   cfg      读面板 NVM 配置（B1h LVDS 设置 / C0h 显示时序）
modprobe spidev 2>/dev/null
python3 - "$1" <<'EOF'
import struct, ctypes, os, sys, time

# ---- ioctl 底层（板上 python 无 fcntl，ctypes 直调 libc）----
libc = ctypes.CDLL(None, use_errno=True)
def ioctl(fd, req, buf):
    r = libc.ioctl(fd, ctypes.c_ulong(req), buf)
    if r < 0:
        raise OSError(ctypes.get_errno(), "ioctl 0x%x" % req)

DEV = "/dev/spidev0.0"
SPI_IOC_WR_MODE          = 0x40016b01   # u8
SPI_IOC_WR_BITS_PER_WORD = 0x40016b03   # u8
SPI_IOC_WR_MAX_SPEED_HZ  = 0x40046b04   # u32
SPI_IOC_MESSAGE_1        = 0x40206b00   # struct spi_ioc_transfer ×1

fd = os.open(DEV, os.O_RDWR)
ioctl(fd, SPI_IOC_WR_MODE,          ctypes.byref(ctypes.c_uint8(0)))    # mode 0
ioctl(fd, SPI_IOC_WR_BITS_PER_WORD, ctypes.byref(ctypes.c_uint8(9)))    # 9-bit DCX 帧
ioctl(fd, SPI_IOC_WR_MAX_SPEED_HZ,  ctypes.byref(ctypes.c_uint32(500000)))  # 500kHz（上限10MHz）

def xfer(words):
    """全双工传一串 9-bit 字；CS 在整个 transfer 内保持有效。
    每个字在缓冲区占 2 字节（小端 u16），dw-apb-ssi 原生支持 9bpw。"""
    n = len(words) * 2
    tx = ctypes.create_string_buffer(b"".join(struct.pack("<H", w) for w in words), n)
    rx = ctypes.create_string_buffer(n)
    # struct spi_ioc_transfer: u64 tx_buf, u64 rx_buf, u32 len, u32 speed_hz,
    #   u16 delay_usecs, u8 bits_per_word, u8 cs_change, u8 tx_nbits, u8 rx_nbits, u16 pad
    t = struct.pack("QQIIHBBBBH", ctypes.addressof(tx), ctypes.addressof(rx),
                    n, 500000, 0, 9, 0, 0, 0, 0)
    ioctl(fd, SPI_IOC_MESSAGE_1, ctypes.create_string_buffer(t, len(t)))
    return [struct.unpack_from("<H", rx.raw, i * 2)[0] & 0x1FF for i in range(len(words))]

# ---- TD7800 9-bit 帧语义 ----
def cmd(c):   xfer([c])            # DCX=0：命令帧（bit8=0）
def param(p): xfer([0x100 | p])    # DCX=1：参数帧（bit8=1）

def write_reg(c, params=()):
    """一个 CS 窗口内：命令帧 + 全部参数帧"""
    xfer([c] + [0x100 | p for p in params])

def read_reg(c, nparams):
    """38h 进读模式 -> 发读命令并继续给哑元时钟采样 SDO -> 39h 退出。
    SDO 输出有 1-bit 相位偏移：把返回字拼成位流，锚定命令回显后按 8-bit 切参数。"""
    xfer([0x038])                                   # enter_read_mode
    rx = xfer([c] + [0x000] * (nparams + 3))        # 读命令 + 哑元，全双工采样
    xfer([0x039])                                   # exit_read_mode
    bs = "".join(format(w, "09b") for w in rx)
    for off in range(0, 18):                        # 容错扫描位偏移
        if off + 8 <= len(bs) and int(bs[off:off + 8], 2) == c:   # 找到回显
            out, k = [], off + 8
            while k + 8 <= len(bs) and len(out) < nparams:
                out.append(int(bs[k:k + 8], 2)); k += 8
            return out
    return None

# ---- 操作分发 ----
op = sys.argv[1] if len(sys.argv) > 1 else "id"

if op == "id":
    p = read_reg(0xBF, 5)
    ok = p and p[:4] == [0x02, 0x3C, 0x68, 0x0A]
    print("BFh =", " ".join("%02X" % v for v in p) if p else "读取失败",
          "<- 通过, IC 活着" if ok else "")

elif op == "bist_on":
    write_reg(0xB0, [0x00])     # 解锁厂商命令
    write_reg(0xD6, [0x00])     # 序列器测试控制
    write_reg(0xDE, [0x01])     # TIGON=1 测试图案开
    print("BIST ON —— 看屏出图案")

elif op == "bist_off":
    write_reg(0xB0, [0x00])
    write_reg(0xDE, [0x00])     # TIGON=0，视频源切回 LVDS 输入
    print("BIST OFF —— 视频源回 LVDS")

elif op == "lighton":           # 厂商 initial code 尾序（文件名"Light on with 11h29h"）
    cmd(0x29); time.sleep(0.2)  # Display On
    cmd(0x11); time.sleep(0.15) # Sleep Out
    print("29h + 11h 已发")

elif op == "cfg":
    b1 = read_reg(0xB1, 7)      # LVDS IF Setting
    c0 = read_reg(0xC0, 7)      # Display Timing
    print("B1h =", " ".join("%02X" % v for v in b1) if b1 else "失败")
    if b1:
        print("  LVFMT=%d(0=VESA) LVCOLMOD=%d(1=24bit4lane) LVSYNM=%d(2=DE+SYNC)"
              % ((b1[0] >> 3) & 1, (b1[0] >> 2) & 1, b1[0] & 3))
        print("  LVHBP=%d LVHFP=%d LVVBP=%d"
              % (((b1[1] & 0xF) << 8) | b1[2], ((b1[3] & 0xF) << 8) | b1[4],
                 ((b1[5] & 0xF) << 8) | b1[6]))
    print("C0h =", " ".join("%02X" % v for v in c0) if c0 else "失败")
    if c0:
        print("  RTN(1H)=%d RCLK  VBP=%d  NL(行数)=%d  VFP=%d"
              % (((c0[0] & 0xF) << 8) | c0[1], c0[2],
                 ((c0[3] & 0xF) << 8) | c0[4], (c0[5] << 8) | c0[6]))

os.close(fd)
EOF
