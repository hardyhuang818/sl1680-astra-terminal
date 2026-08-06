#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""收 13 个依赖 recipe 的全部运行时 deb（排除 dev/dbg/doc/src/locale）打成 tar"""
import glob, os, tarfile

B = "/home/astra/sdk/build-sl1680"
D = B + "/tmp/deploy/deb"
KEYS = ["at-spi2-core", "atk", "brotli", "dav1d", "flite", "libhwy", "highway",
        "lcms", "avif", "backtrace", "epoxy", "jxl", "xslt", "woff2"]
BAD = ("-dev_", "-dbg_", "-doc_", "-src_", "-staticdev_", "-locale", "-bin_", "-tools_")

picked = {}
for k in KEYS:
    for f in glob.glob("%s/*/*%s*_*.deb" % (D, k)):
        b = os.path.basename(f)
        if any(x in b for x in BAD):
            continue
        if "tflite" in b:                      # flite 关键词的误抓
            continue
        picked[b] = f

tar = B + "/dep_debs.tar"
with tarfile.open(tar, "w") as t:
    for b, f in sorted(picked.items()):
        t.add(f, arcname=b)
        print("  %7.2f MB  %s" % (os.path.getsize(f) / 1048576, b))
print("共 %d 个 -> %s (%.1f MB)" % (len(picked), tar, os.path.getsize(tar) / 1048576))
