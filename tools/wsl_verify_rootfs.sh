#!/bin/bash
D=/home/astra/sdk/build-sl1680/tmp/deploy/images/sl1680
IMG=$(ls -t $D/astra-media-sl1680.rootfs-*.ext4 2>/dev/null | head -n 1)
echo "镜像: $(basename $IMG)  ($(stat -c %s $IMG) 字节)"
echo
echo "════ ★ 直接从 ext4 里查我们的文件(debugfs, 免挂载) ════"
for f in /usr/bin/astra_voice /usr/bin/dl_face /usr/bin/astra_wait_mic.sh /usr/bin/astra_setvol.sh \
         /usr/lib/libsherpa-onnx-c-api.so /usr/lib/libonnxruntime.so /usr/lib/libdlsdk.so \
         /home/voice/astra_llm.py /home/voice/astra_translate.py /home/voice/silent.wav \
         /etc/asound.conf /etc/astra/llm.conf.sample \
         /usr/lib/systemd/system/astra-voice.service /usr/lib/systemd/system/dl-face.service \
         /usr/bin/synap_cli_od /usr/share/fonts/ttf/wqy-zenhei.ttf ; do
  r=$(debugfs -R "stat $f" "$IMG" 2>/dev/null | grep -m1 "Size:" | grep -oE "Size: [0-9]+" | cut -d' ' -f2)
  if [ -n "$r" ]; then printf "  ✓ %-46s %s 字节\n" "$f" "$r"; else printf "  ✗ %-46s 不存在\n" "$f"; fi
done

echo
echo "════ 开机自启会不会真的生效(systemd preset) ════"
debugfs -R "cat /usr/lib/systemd/system-preset/98-astra-voice.preset" "$IMG" 2>/dev/null | sed 's/^/  /'
echo "  multi-user.target.wants 里的软链:"
debugfs -R "ls -l /etc/systemd/system/multi-user.target.wants" "$IMG" 2>/dev/null | grep -iE "astra|dl-face|vision" | awk '{print "    "$NF}'

echo
echo "════ synaimg(烧录格式)产出了吗 ════"
ls -lt $D/*.subimg $D/*.img $D/SYNAIMG* 2>/dev/null | head -n 8 | awk '{printf "  %12s  %s\n",$5,$9}'
ls -d $D/synaimg 2>/dev/null && ls $D/synaimg | head -n 10 | sed 's/^/    /'
