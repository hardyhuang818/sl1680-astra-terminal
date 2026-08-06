#!/bin/sh
SM=/sys/kernel/debug/pinctrl/f7fe2c10.pinctrl-berlin-pinctrl
echo "===== pinmux-pins 全文（SM 域 SPI2 五根线）====="
grep -n -i "spi2" "$SM/pinmux-pins"
echo
echo "===== spi 控制器驱动 ====="
readlink -f /sys/bus/spi/devices/spi0.0/../ | head -n 1
ls -l /sys/bus/platform/devices/f7fca000.spi/driver 2>/dev/null | sed 's/.*-> //'
echo
echo "===== 低速 + 0xFF 填充再试 ====="
cd /home/voice
python3 - <<'EOF'
import os
os.environ["EB_SPI_HZ"] = "100000"
import importlib, sys
sys.path.insert(0, "/home/voice")
import eb7928_spi as S
import eb7928
# 猴补：读请求改发全 0xFF 试一次（有的实现用 $FF 请求读）
orig = S.SpiBus._xfer
class FFBus(S.SpiBus):
    def read(self, n):
        rx = self._xfer(b"\xff" * n)
        import time; time.sleep(2e-4)
        return rx
for name, bus_cls, mode in (("0x00填充 mode0", S.SpiBus, 0), ("0xFF填充 mode0", FFBus, 0),
                            ("0x00填充 mode3", S.SpiBus, 3), ("0xFF填充 mode3", FFBus, 3)):
    S.MODE = mode
    b = bus_cls()
    try:
        b.write(eb7928.build(eb7928.CMD_IDENTIFY, b"", 1))
        rx = b.read(4)
        print("%-16s 读回: %s" % (name, rx.hex()))
    except Exception as e:
        print("%-16s 异常: %s" % (name, e))
    finally:
        b.close()
EOF
