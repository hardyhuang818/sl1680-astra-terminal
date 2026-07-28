#!/bin/sh
# 启动前复位 DisplayLink 设备。
#
# 背景(实测结论)：如果上一个进程没干净 teardown 就被杀，DL7400 会卡在被占用状态，
# 之后 dlsdk_get_devices() 一直返回 0 个设备。
#   * echo 0/1 > authorized        -> 救不回来
#   * usb 驱动 unbind/bind          -> 能救回来  ← 用这个
#
# 动态找 DisplayLink(VID 17e9) 的 USB 路径，不写死 2-1.4.1。

for dev in /sys/bus/usb/devices/*/; do
    [ -f "$dev/idVendor" ] || continue
    [ "$(cat "$dev/idVendor" 2>/dev/null)" = "17e9" ] || continue

    path=$(basename "$dev")
    # 只处理设备本身(形如 2-1.4.1)，跳过接口(带冒号的)
    case "$path" in *:*) continue ;; esac

    echo "dl-clock-reset: 复位 DisplayLink $path"
    echo -n "$path" > /sys/bus/usb/drivers/usb/unbind 2>/dev/null
    sleep 3
    echo -n "$path" > /sys/bus/usb/drivers/usb/bind 2>/dev/null
    sleep 5
    echo "dl-clock-reset: 完成 (speed=$(cat "$dev/speed" 2>/dev/null)M)"
done

exit 0
