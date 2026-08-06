#!/bin/sh
cd /home/voice
for f in eb7928.py eb7928_spi.py; do
  sed -i '1s/^\xef\xbb\xbf//' "$f"
done
rm -rf __pycache__
python3 eb7928_spi.py faildet
