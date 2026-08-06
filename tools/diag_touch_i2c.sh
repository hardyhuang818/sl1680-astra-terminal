#!/bin/sh
# 两个待查项：touch_irq 归零 是不是触摸坏了；舵机写 Errno 121 是不是被拔了
echo "===== 触摸 ====="
echo "-- /proc/interrupts 里的 synaptics --"
grep -i synaptics /proc/interrupts || echo "  (没有注册的中断行!)"
echo "-- 驱动/设备 --"
ls /sys/bus/i2c/drivers/synaptics_tcm_i2c/ 2>/dev/null | grep -v bind | grep -v uevent || echo "  (驱动目录为空)"
echo "-- input 设备 --"
for d in /sys/class/input/input*; do
  n=$(cat $d/name 2>/dev/null)
  case "$n" in *[Ss]ynaptics*|*[Tt]ouch*|*tcm*) echo "  $d -> $n";; esac
done
grep -i -E 'synaptics|tcm' /proc/bus/input/devices | head -20
echo "-- 最近的 touch 内核日志 --"
dmesg | grep -i -E 'synaptics|tcm|touch' | tail -8

echo
echo "===== I2C / 舵机 ====="
echo "-- i2c 总线 --"
ls /dev/i2c-* 2>/dev/null
echo "-- i2c-0 上有谁 (只读探测) --"
python3 - <<'EOF'
import os, ctypes
libc = ctypes.CDLL(None, use_errno=True)
found = []
for addr in list(range(0x08, 0x78)):
    try:
        fd = os.open("/dev/i2c-0", os.O_RDWR)
    except OSError:
        print("  打不开 /dev/i2c-0"); break
    try:
        if libc.ioctl(fd, ctypes.c_ulong(0x0703), ctypes.c_ulong(addr)) < 0:
            continue
        try:
            os.read(fd, 1)          # 纯读，无副作用
            found.append(hex(addr))
        except OSError:
            pass
    finally:
        os.close(fd)
print("  应答的地址:", " ".join(found) if found else "(无)")
print("  期望: 0x40=INA3221  0x41=INA3221#2  0x40/0x70=PCA9685(All Call)")
EOF
echo "-- hwmon (INA3221 是否还在读数) --"
for h in /sys/class/hwmon/hwmon*; do
  nm=$(cat $h/name 2>/dev/null)
  case "$nm" in *ina3221*) echo "  $h = $nm : $(cat $h/in1_label 2>/dev/null)=$(cat $h/in1_input 2>/dev/null)mV";; esac
done
