#!/bin/bash
# Both required SRCREVs are the branch tip, so a shallow single-branch bare
# clone (which the flaky link CAN complete) contains exactly what bitbake needs.
# Place them at bitbake's git2 mirror paths.
DL=/home/astra/sdk/build-sl2619/downloads/git2
BR=scarthgap_6.12_v2.3.0
mkdir -p "$DL"

shallow() {
    local url="$1" dest="$2" n=0
    while [ $n -lt 15 ]; do
        n=$((n+1))
        echo "[$url] shallow bare clone attempt $n"
        rm -rf "$dest.tmp"
        git clone --bare --depth 1 --single-branch --branch "$BR" "$url" "$dest.tmp"
        if [ $? -eq 0 ] && git -C "$dest.tmp" rev-parse HEAD >/dev/null 2>&1; then
            # make it look like a bitbake mirror: fetch-all refspec + bare
            git -C "$dest.tmp" config remote.origin.url "$url"
            git -C "$dest.tmp" config remote.origin.fetch "+refs/*:refs/*"
            rm -rf "$dest"; mv "$dest.tmp" "$dest"
            echo "  OK: $(git -C "$dest" rev-parse HEAD)"
            return 0
        fi
        echo "  failed, retry in 6s"; sleep 6
    done
    echo "  GAVE UP: $url"; return 1
}

shallow https://github.com/synaptics-astra/ta_enc \
        "$DL/github.com.synaptics-astra.ta_enc"
shallow https://github.com/synaptics-astra/boot-preboot-prebuilts \
        "$DL/github.com.synaptics-astra.boot-preboot-prebuilts"

echo
echo "### verify required SRCREVs are present locally ###"
git -C "$DL/github.com.synaptics-astra.ta_enc" cat-file -e 83ad0847bbdc21be6df65ec4fb6d4b0cd6de9b61 2>/dev/null && echo "ta_enc srcrev present" || echo "ta_enc srcrev MISSING"
git -C "$DL/github.com.synaptics-astra.boot-preboot-prebuilts" cat-file -e 37aa5ede4fd304db5d4d70c77e6eaac0ab8873ae 2>/dev/null && echo "preboot srcrev present" || echo "preboot srcrev MISSING"
