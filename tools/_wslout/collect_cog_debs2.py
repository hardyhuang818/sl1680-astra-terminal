#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""收 cog 运行时闭包中板上缺的 deb（v2：处理 debian 改名）

v1 的坑：pkgdata RDEPENDS 用的是 OE 包名（cairo/glibc/glib-2.0），
而 manifest 和 deb 文件名用的是 debian 改名后的（libcairo2/libc6/libglib-2.0-0）。
必须读每个包 pkgdata 里的 `PKG:<name>:` 映射后再比对。
"""
import glob, os, re, shutil

B = "/home/astra/sdk/build-sl1680"
PKGDATA = B + "/tmp/pkgdata/sl1680/runtime"
DEBDIR = B + "/tmp/deploy/deb"
MANIFEST = B + "/tmp/deploy/images/sl1680/astra-media-sl1680.rootfs.manifest"
OUT = B + "/cog_debs"

def pkg_info(pkg):
    """返回 (renamed_pkg_name, [rdeps]) 或 None"""
    p = os.path.join(PKGDATA, pkg)
    if not os.path.exists(p):
        return None
    renamed, deps = pkg, []
    for ln in open(p, encoding="utf-8", errors="replace"):
        m = re.match(r"PKG[:_]%s: (\S+)" % re.escape(pkg), ln)
        if m:
            renamed = m.group(1)
        m = re.match(r"RDEPENDS[:_]%s: (.*)" % re.escape(pkg), ln)
        if m:
            deps += re.findall(r"([A-Za-z0-9][A-Za-z0-9+.\-]*)(?:\s*\([^)]*\))?", m.group(1))
    return renamed, deps

have = set()
for ln in open(MANIFEST):
    parts = ln.split()
    if parts:
        have.add(parts[0])
print("manifest 已有 %d 个包" % len(have))

todo, seen, renamed_of, nometa = ["cog"], set(), {}, []
while todo:
    pkg = todo.pop()
    if pkg in seen:
        continue
    seen.add(pkg)
    info = pkg_info(pkg)
    if info is None:
        nometa.append(pkg)
        continue
    renamed_of[pkg] = info[0]
    todo += [d for d in info[1] if d not in seen]

print("闭包 %d 个包(无 pkgdata: %s)" % (len(seen), nometa))
need = sorted((p, renamed_of[p]) for p in renamed_of
              if renamed_of[p] not in have)
print("板上缺 %d 个" % len(need))

os.makedirs(OUT, exist_ok=True)
for f in glob.glob(OUT + "/*.deb"):
    os.remove(f)
total, notfound = 0, []
for oe, deb in need:
    hits = glob.glob("%s/*/%s_*.deb" % (DEBDIR, deb))
    if hits:
        f = sorted(hits)[-1]
        shutil.copy2(f, OUT)
        total += os.path.getsize(f)
    else:
        notfound.append("%s(%s)" % (deb, oe))

n = len(glob.glob(OUT + "/*.deb"))
print()
print("收了 %d 个 deb -> %s  共 %.1f MB" % (n, OUT, total / 1048576))
if notfound:
    print("找不到 deb(%d):" % len(notfound), notfound)
print()
for f in sorted(glob.glob(OUT + "/*.deb"), key=os.path.getsize, reverse=True):
    print("  %7.2f MB  %s" % (os.path.getsize(f) / 1048576, os.path.basename(f)))
