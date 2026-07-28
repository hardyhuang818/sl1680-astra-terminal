#!/bin/bash
PSEUDO=/home/astra/sdk/build-sl1680/tmp/sysroots-components/x86_64/pseudo-native/usr/bin/pseudo
PSEUDO_LIBDIR=/home/astra/sdk/build-sl1680/tmp/sysroots-components/x86_64/pseudo-native/usr/lib/pseudo/lib64

echo "############ minimal repro: tar -C <dir> -x under pseudo ############"
rm -rf /tmp/ptest; mkdir -p /tmp/ptest/src/a/b; echo hi > /tmp/ptest/src/a/b/f.txt; mkdir -p /tmp/ptest/dst
cd /tmp/ptest
echo "-- WITHOUT pseudo --"
tar -cf - -C src -p -S . | tar -xf - -C dst && echo "OK-no-pseudo" || echo "FAIL-no-pseudo"
rm -rf /tmp/ptest/dst; mkdir -p /tmp/ptest/dst
echo "-- WITH pseudo --"
"$PSEUDO" bash -c 'cd /tmp/ptest && tar -cf - -C src -p -S . | tar -xf - -C dst' && echo "OK-pseudo" || echo "FAIL-pseudo"

echo
echo "############ does pseudo wrapper table include openat2 / statx? ############"
WRAP=/home/astra/sdk/build-sl1680/tmp/sysroots-components/x86_64/pseudo-native/usr/lib/pseudo/lib64/libpseudo.so
for sym in openat openat2 open64 mkdirat statx newfstatat fstatat64; do
  if nm -D "$WRAP" 2>/dev/null | grep -qw "$sym"; then echo "  wrapped: $sym"; else echo "  MISSING: $sym"; fi
done

echo
echo "############ strace the failing at-syscall (which syscall tar uses for -C) ############"
which strace >/dev/null 2>&1 && {
  rm -rf /tmp/ptest/dst; mkdir -p /tmp/ptest/dst
  cd /tmp/ptest
  strace -f -e trace=open,openat,openat2,mkdir,mkdirat -o /tmp/tar_strace.txt tar -xf <(tar -cf - -C src .) -C dst 2>/dev/null
  echo "-- open/at syscalls tar used on dst --"
  grep -E 'dst|openat2|mkdirat' /tmp/tar_strace.txt 2>/dev/null | head -15
} || echo "(strace not installed)"
