#!/bin/sh
# 纯只读：0x44/0x47/0x48 到底是不是 PCA9685？(不写任何寄存器，不让舵机动)
python3 - <<'EOF'
import os, ctypes
libc = ctypes.CDLL(None, use_errno=True)

def rd(addr, reg, n=1):
    fd = os.open("/dev/i2c-0", os.O_RDWR)
    try:
        if libc.ioctl(fd, ctypes.c_ulong(0x0706), ctypes.c_ulong(addr)) < 0:
            return None
        os.write(fd, bytes([reg]))
        return list(os.read(fd, n))
    except OSError as e:
        return "ERR:%s" % e.errno
    finally:
        os.close(fd)

# PCA9685 指纹: MODE1(0x00) MODE2(0x01) SUBADR1..3(0x02-04)=0xE2,0xE4,0xE8,
#               ALLCALLADR(0x05)=0xE0, PRE_SCALE(0xFE)
print("addr  MODE1 MODE2 SUB1 SUB2 SUB3 ALLCALL PRESCALE   判定")
for a in (0x44, 0x47, 0x48, 0x70):
    v = [rd(a, r) for r in (0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0xFE)]
    def f(x): return "ERR" if not isinstance(x, list) else "%02x" % x[0]
    cells = [f(x) for x in v]
    # PCA9685 出厂 SUBADR = E2/E4/E8, ALLCALLADR = E0 —— 这是最硬的指纹
    isp = (cells[2], cells[3], cells[4], cells[5]) == ("e2", "e4", "e8", "e0")
    print(" 0x%02x   %s    %s   %s   %s   %s    %s      %s   %s" %
          (a, cells[0], cells[1], cells[2], cells[3], cells[4], cells[5], cells[6],
           "★ 是 PCA9685" if isp else "不是 PCA9685"))
EOF
