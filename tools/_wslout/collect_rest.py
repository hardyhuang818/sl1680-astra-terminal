#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 13 个名字对不上的依赖按关键词宽松抓齐（只要运行时库包，排除 dev/dbg/doc/src/staticdev）"""
import glob, os, shutil

B = "/home/astra/sdk/build-sl1680"
DEBDIR = B + "/tmp/deploy/deb"
OUT = B + "/cog_debs"

KEYS = ["at-spi2", "atspi", "brotli", "dav1d", "flite", "highway", "hwy",
        "lcms", "avif", "backtrace", "epoxy", "jxl", "libwpe", "xslt", "woff2"]
BAD = ("-dev_", "-dbg_", "-doc_", "-src_", "-staticdev_", "-locale-", "-dbgsym")

got = 0
for k in KEYS:
    for f in glob.glob("%s/*/*%s*_*.deb" % (DEBDIR, k)):
        b = os.path.basename(f)
        if any(x in b for x in BAD):
            continue
        dst = os.path.join(OUT, b)
        if not os.path.exists(dst):
            shutil.copy2(f, OUT)
            got += 1

files = sorted(glob.glob(OUT + "/*.deb"))
total = sum(os.path.getsize(f) for f in files)
print("补了 %d 个，现共 %d 个 deb，%.1f MB" % (got, len(files), total / 1048576))
for f in files:
    print("  %7.2f MB  %s" % (os.path.getsize(f) / 1048576, os.path.basename(f)))
# 打个 tar 方便传输
import tarfile
tar = B + "/cog_debs.tar"
with tarfile.open(tar, "w") as t:
    for f in files:
        t.add(f, arcname=os.path.basename(f))
print("tar:", tar, "%.1f MB" % (os.path.getsize(tar) / 1048576))
