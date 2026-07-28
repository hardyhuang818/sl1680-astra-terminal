#!/bin/bash
# Compile the openat2->ENOSYS launcher and test it fixes pseudo tar.
PSEUDO=/home/astra/sdk/build-sl1680/tmp/sysroots-components/x86_64/pseudo-native/usr/bin/pseudo

gcc -O2 -o /home/astra/no_openat2 /home/astra/no_openat2.c && echo "compiled no_openat2" || { echo "COMPILE FAILED"; exit 1; }

echo
echo "### confirm it forces tar to avoid openat2 (strace) ###"
rm -rf /tmp/ptest; mkdir -p /tmp/ptest/src/a/b /tmp/ptest/dst; echo hi > /tmp/ptest/src/a/b/f.txt
cd /tmp/ptest
strace -f -e trace=openat2,openat -o /tmp/st.txt /home/astra/no_openat2 tar -xf <(tar -cf - -C src .) -C dst 2>/dev/null
echo "openat2 calls (should be ENOSYS or none):"; grep -c openat2 /tmp/st.txt
grep 'openat2' /tmp/st.txt | head -2

echo
echo "### minimal pseudo tar WITH the fix ###"
rm -rf /tmp/ptest/dst; mkdir -p /tmp/ptest/dst
"$PSEUDO" bash -c 'cd /tmp/ptest && tar -cf - -C src -p -S . | /home/astra/no_openat2 tar -xf - -C dst' \
  && echo ">>> PSEUDO-TAR-FIX: OK" || echo ">>> PSEUDO-TAR-FIX: FAIL"
echo "extracted:"; find /tmp/ptest/dst
