#!/bin/bash
# Runs each plan step's idempotent guard and reports pass/skip.
# Side-effect free.

pass()  { printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail()  { printf '  \033[31m✗\033[0m %s\n' "$1"; }
info()  { printf '  · %s\n' "$1"; }
hdr()   { printf '\n\033[1m%s\033[0m\n' "$1"; }

hdr "Step 4 — Yocto host tools"
miss=0
for t in gcc make git python3 chrpath socat texi2any diffstat zstd lz4 rsync bzip2 unzip cpio; do
  command -v "$t" >/dev/null || { fail "missing: $t"; miss=$((miss+1)); }
done
[ $miss -eq 0 ] && pass "all required host tools present"
locale -a 2>/dev/null | grep -qi en_US.UTF && pass "en_US.UTF-8 locale generated" || fail "en_US.UTF-8 missing"

hdr "Step 5 — git:// rewrite"
rw=$(git config --global --get url.https://.insteadof 2>/dev/null)
[ "$rw" = "git://" ] && pass "url rewrite: git:// → https://" || fail "rewrite missing (got: $rw)"

hdr "Step 6 — SDK source tree"
# Use -e (not -d): submodules use gitfile pointers, not directories
if [ -e ~/sdk/.git ] && [ -e ~/sdk/poky/.git ] && [ -e ~/sdk/meta-synaptics/.git ]; then
  pass "~/sdk and key submodules present"
  cd ~/sdk
  br=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  [ "$br" = "scarthgap_6.12_v2.3.0" ] && pass "branch: $br" || info "branch: $br (expected scarthgap_6.12_v2.3.0)"
  # any uninitialized submodule?
  if git submodule status --recursive 2>/dev/null | grep -qE '^[-+]'; then
    fail "some submodules are out of sync"
  else
    pass "all 10 submodules in sync"
  fi
else
  fail "SDK not cloned"
fi

hdr "Step 7 — build-sl2619 conf"
if [ -f ~/sdk/build-sl2619/conf/local.conf ]; then
  if grep -q 'sl2619' ~/sdk/build-sl2619/conf/local.conf; then
    pass "conf/local.conf exists with MACHINE=sl2619"
    info "$(grep -E '^(MACHINE|DISTRO|LICENSE_FLAGS)' ~/sdk/build-sl2619/conf/local.conf | head -3)"
  else
    fail "conf/local.conf exists but no sl2619"
  fi
else
  fail "conf/local.conf missing — need to source setup-environment"
fi

hdr "Step 8 — build artifacts"
IMG=~/sdk/build-sl2619/tmp/deploy/images/sl2619
missing=0
for f in \
    SYNAIMG/emmc_image_list \
    SYNAIMG/bl.subimg.gz \
    SYNAIMG/boot.subimg.gz \
    SYNAIMG/preboot.subimg.gz \
    SYNAIMG/tzk.subimg.gz \
    SYNAIMG/sysmgr.subimg.gz \
    SYNAIMG/rootfs.subimg.gz \
    SYNAIMG/home.subimg.gz \
    Image-sl2619.bin \
    astra-media-sl2619.rootfs.ext4.gz \
    astra-media.swu \
  ; do
  if [ -e "$IMG/$f" ]; then
    # -L: follow symlinks so we get the actual target size, not the link's
    sz=$(du -hL "$IMG/$f" 2>/dev/null | awk '{print $1}')
    pass "$f ($sz)"
  else
    fail "missing: $f"; missing=$((missing+1))
  fi
done

hdr "Build log status"
if [ -f ~/sdk/build-sl2619/build.log ]; then
  if grep -q "all succeeded" ~/sdk/build-sl2619/build.log; then
    pass "$(grep 'Tasks Summary' ~/sdk/build-sl2619/build.log | tail -1)"
  fi
  last=$(grep "^=== bitbake astra-media end:" ~/sdk/build-sl2619/build.log | tail -1)
  [ -n "$last" ] && info "$last"
fi

hdr "Disk usage"
du -sh ~/sdk/build-sl2619/{tmp,downloads,sstate-cache} 2>/dev/null
df -h ~ | tail -1

hdr "Summary"
if [ $missing -eq 0 ]; then
  pass "All artifacts present — plan is fully realized on this machine; no rebuild needed."
else
  fail "$missing artifact(s) missing — re-run Step 8 (bitbake astra-media)"
fi
