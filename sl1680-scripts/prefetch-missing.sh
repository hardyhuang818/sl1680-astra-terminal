#!/bin/bash
# Robustly pre-clone the two repos whose do_fetch keeps hitting github TLS
# drops, into bitbake's git2 mirror cache so the next build finds them.
DL=/home/astra/sdk/build-sl2619/downloads/git2
mkdir -p "$DL"

clone_retry() {
    local url="$1" dest="$2" n=0
    if [ -d "$dest" ] && git -C "$dest" rev-parse --git-dir >/dev/null 2>&1; then
        echo "[$dest] already present, updating…"
        git -C "$dest" remote update --prune 2>/dev/null && { echo "  OK (updated)"; return 0; }
    fi
    while [ $n -lt 12 ]; do
        n=$((n+1))
        echo "[$url] clone attempt $n → $dest"
        rm -rf "$dest.tmp"
        git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=60 \
            -c http.postBuffer=524288000 \
            clone --bare --mirror "$url" "$dest.tmp"
        rc=$?
        if [ $rc -eq 0 ] && git -C "$dest.tmp" rev-parse --git-dir >/dev/null 2>&1; then
            rm -rf "$dest"; mv "$dest.tmp" "$dest"
            echo "  OK ($(git -C "$dest" rev-list --all --count 2>/dev/null) commits)"; return 0
        fi
        echo "  failed (rc=$rc), retrying in 8s…"; sleep 8
    done
    echo "  GAVE UP on $url"; return 1
}

clone_retry https://github.com/synaptics-astra/ta_enc \
            "$DL/github.com.synaptics-astra.ta_enc"
clone_retry https://github.com/synaptics-astra/boot-preboot-prebuilts \
            "$DL/github.com.synaptics-astra.boot-preboot-prebuilts"

echo
echo "### also warm torq repos (parse-time ls-remote) ###"
clone_retry https://github.com/synaptics-torq/TIM-VX \
            "$DL/github.com.synaptics-torq.TIM-VX" 2>/dev/null
clone_retry https://github.com/synaptics-torq/torq-compiler \
            "$DL/github.com.synaptics-torq.torq-compiler" 2>/dev/null

echo
echo "### present now: ###"
ls -d "$DL"/github.com.synaptics-astra.ta_enc "$DL"/github.com.synaptics-astra.boot-preboot-prebuilts 2>/dev/null
