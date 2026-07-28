#!/bin/bash
echo "verify tools:"
for t in gcc make git python3 chrpath socat texi2any diffstat zstd lz4 wget bzip2 rsync unzip cpio; do
  if command -v "$t" >/dev/null; then
    echo "  ok: $t"
  else
    echo "  MISS: $t"
  fi
done
echo "---"
locale -a | grep -i en_US || echo "no en_US locale yet"
