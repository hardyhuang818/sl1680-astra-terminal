#!/bin/sh
echo "=== 板上所有 libusb ==="
ls -la /usr/lib/libusb* /lib/libusb* 2>/dev/null
echo
echo "=== 每个 libusb 的版本字符串 ==="
for f in /usr/lib/libusb-1.0.so.0 /usr/lib/libusb-1.0.so.0.4.0; do
  [ -f "$f" ] || continue
  echo "--- $f ---"
  strings "$f" 2>/dev/null | grep -iE "^1\.0\.[0-9]+|libusb-1\.0\.[0-9]+|http.*libusb" | head -n 3
  echo -n "  导出 hotplug 符号: "
  (nm -D --defined-only "$f" 2>/dev/null || readelf -sW --dyn-syms "$f" 2>/dev/null) | grep -c hotplug
done
echo
echo "=== libdlsdk.so 运行时实际链到哪个 libusb ==="
ldd /usr/lib/libdlsdk.so 2>/dev/null | grep -i usb
echo "(找不到就试 dl_face 的依赖)"
ldd /usr/bin/dl_face 2>/dev/null | grep -iE "usb|dlsdk"
echo
echo "=== libdlsdk.so 位置 ==="
find / -name "libdlsdk.so*" 2>/dev/null | head -n 5
echo
echo "=== dl_hptest 进程实际加载的库(跑起来看 maps) ==="
/tmp/dl_hptest >/dev/null 2>&1 &
P=$!
sleep 1
grep -iE "libusb|libdlsdk" /proc/$P/maps 2>/dev/null | awk '{print $NF}' | sort -u
wait $P 2>/dev/null
