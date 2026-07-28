#!/bin/bash
set -e
# Rewrite all git:// URLs to https:// (git.yoctoproject.org blocks 9418 commonly,
# and GitHub itself deprecated git:// in 2022).
git config --global url."https://".insteadOf "git://"
echo "URL rewrite installed:"
git config --global --get-regexp 'url\..*\.insteadof' || true

cd ~/sdk

# Re-init submodules and try again. -f forces, -r recursive.
git submodule sync --recursive
git submodule update --init --recursive --progress 2>&1 | tail -80
echo "submodule status:"
git submodule status --recursive | head -40
echo "---"
echo "missing (empty) submodule paths, if any:"
git submodule foreach --recursive 'test -z "$(ls -A)" && echo "EMPTY: $sm_path"' 2>/dev/null || true
