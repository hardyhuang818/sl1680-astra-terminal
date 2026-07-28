#!/bin/bash
# Build astra-media for MACHINE=sl1680 (dolphin), reusing sl2619's downloads +
# sstate-cache so the shared kernel 6.12.62 / toolchain artifacts hit cache.
#
# NOTE: deliberately NO `set -e` around the bitbake loop — a transient git-clone
# fetch drop makes bitbake return non-zero, and `set -e` would abort before the
# retry loop can react. We guard the setup steps individually instead.
cd ~/sdk || exit 1
export MACHINE=sl1680
export ACCEPT_SYNA_EULA=1

# Kill any stale bitbake cooker daemon so the fresh build inherits our
# wrapper-augmented PATH (a persisted daemon keeps its old PATH/hosttools).
pkill -9 -f 'bitbake-server' 2>/dev/null
pkill -9 -f 'bitbake/bin/bitbake' 2>/dev/null
sleep 2

. meta-synaptics/setup/setup-environment || { echo "setup-environment failed"; exit 1; }

# Point DL_DIR / SSTATE_DIR at the already-populated sl2619 caches (idempotent).
CONF=~/sdk/build-sl1680/conf/local.conf
grep -q 'REUSE-SL2619-CACHE' "$CONF" || cat >> "$CONF" <<'EOF'

# --- REUSE-SL2619-CACHE : share downloads + sstate with the sl2619 build ---
DL_DIR = "/home/astra/sdk/build-sl2619/downloads"
SSTATE_DIR = "/home/astra/sdk/build-sl2619/sstate-cache"
# Use cached git SRCREV instead of a live ls-remote on every parse — stops
# flaky github TLS drops from halting parsing (torq-runtime etc.).
BB_SRCREV_POLICY = "cache"
EOF

# Register the TD7800 touch + LVDS layer (idempotent).
# NOTE: use an absolute path — ${TOPDIR} is a bitbake var, NOT a shell var,
# so it expands empty here.
bitbake-layers show-layers 2>/dev/null | grep -q 'meta-tcm2-touch' \
    || bitbake-layers add-layer /home/astra/sdk/meta-tcm2-touch

# --- WSL2 pseudo/openat2 workaround (idempotent) ---
# GNU tar 1.34 uses the openat2() raw syscall (RESOLVE_BENEATH), which poky's
# LD_PRELOAD-based pseudo cannot intercept -> do_package/do_rootfs fail with
# "unknown base path for fd N / mkdir: Bad address". Route tar & friends
# through a tiny seccomp launcher that forces openat2 -> ENOSYS, making tar
# fall back to plain openat() (which pseudo wraps).
if [ ! -x /home/astra/no_openat2 ]; then
    gcc -O2 -o /home/astra/no_openat2 /home/astra/no_openat2.c
fi
mkdir -p /home/astra/toolwrap
for t in tar cp rsync install mv ln mkdir cpio bzip2 gzip pigz; do
    real=$(command -v "$t" 2>/dev/null); [ -z "$real" ] && continue
    printf '#!/bin/sh\nexec /home/astra/no_openat2 %s "$@"\n' "$real" > "/home/astra/toolwrap/$t"
    chmod +x "/home/astra/toolwrap/$t"
done
export PATH="/home/astra/toolwrap:$PATH"
# Drop stale hosttools symlinks so bitbake re-points them at the wrappers.
for t in tar cp rsync install mv ln mkdir cpio bzip2 gzip; do
    rm -f "$BUILDDIR/tmp/hosttools/$t" 2>/dev/null
done

LOG=~/sdk/build-sl1680/build.log
{
  echo "=== bitbake astra-media (sl1680) start: $(date -Iseconds) ==="
  echo "BUILDDIR: $BUILDDIR"
  # Retry up to 3x to ride out transient git-clone/network drops
  # (bitbake resumes from sstate + already-fetched sources each time).
  EXIT=1
  # --continue: keep building other tasks after a fetch failure so each pass
  # makes maximum progress; up to 5 passes to ride out flaky git mirrors.
  for attempt in 1 2 3 4 5; do
    echo "--- bitbake attempt $attempt $(date -Iseconds) ---"
    bitbake --continue astra-media
    EXIT=$?
    [ $EXIT -eq 0 ] && break
    echo "--- attempt $attempt failed (exit=$EXIT), retrying in 20s ---"
    sleep 20
  done
  echo "=== bitbake astra-media (sl1680) end: $(date -Iseconds) exit=$EXIT ==="
} >>"$LOG" 2>&1
