#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""收集 cog 的完整运行时依赖闭包中、板上镜像还没有的 .deb

原理：
  tmp/pkgdata/sl1680/runtime/<pkg> 里有每个包的 RDEPENDS_<pkg> ——
  从 cog 出发 BFS 走完闭包；减掉 astra-media manifest（板上已有）；
  再把包名映射到 tmp/deploy/deb 下的实际 deb 文件，拷到暂存目录。
"""
import glob, os, re, shutil, sys

B = "/home/astra/sdk/build-sl1680"
PKGDATA = B + "/tmp/pkgdata/sl1680/runtime"
DEBDIR = B + "/tmp/deploy/deb"
MANIFEST = B + "/tmp/deploy/images/sl1680/astra-media-sl1680.rootfs.manifest"
OUT = B + "/cog_debs"

def read_rdeps(pkg):
    p = os.path.join(PKGDATA, pkg)
    if not os.path.exists(p):
        return None
    deps = []
    for ln in open(p, encoding="utf-8", errors="replace"):
        m = re.match(r"RDEPENDS[:_]%s: (.*)" % re.escape(pkg), ln)
        if m:
            # 形如: pkgA (>= 1.2) pkgB pkgC (>= x)
            deps += re.findall(r"([a-z0-9][a-z0-9+.\-]*)(?:\s*\([^)]*\))?", m.group(1))
    return deps

# 板上已有的包
have = set()
if os.path.exists(MANIFEST):
    for ln in open(MANIFEST):
        parts = ln.split()
        if parts:
            have.add(parts[0])
print("镜像 manifest 已有 %d 个包" % len(have))

# BFS 闭包
todo, seen, missing_meta = ["cog"], set(), []
while todo:
    pkg = todo.pop()
    if pkg in seen:
        continue
    seen.add(pkg)
    deps = read_rdeps(pkg)
    if deps is None:
        missing_meta.append(pkg)
        continue
    todo += [d for d in deps if d not in seen]

print("cog 运行时闭包: %d 个包" % len(seen))
need = sorted(p for p in seen if p not in have)
print("板上缺的: %d 个" % len(need))

# 包名 -> deb 文件（deb 名里 _ 替换规则：包名保持，版本任意）
os.makedirs(OUT, exist_ok=True)
for f in glob.glob(OUT + "/*.deb"):
    os.remove(f)
found, notfound, total = [], [], 0
for p in need:
    hits = glob.glob("%s/*/%s_*.deb" % (DEBDIR, p))
    # 过滤掉误匹配（foo_1.0 会匹到 foo-bar_1.0 吗？不会，glob 已锚定 _）
    if hits:
        f = sorted(hits)[-1]
        shutil.copy2(f, OUT)
        total += os.path.getsize(f)
        found.append(p)
    else:
        notfound.append(p)

print()
print("已收 %d 个 deb -> %s  (共 %.1f MB)" % (len(found), OUT, total / 1048576))
if notfound:
    print("找不到 deb 的(%d, 多为虚包/内核符号包, 一般可忽略):" % len(notfound))
    for p in notfound[:20]:
        print("   ", p)
if missing_meta:
    print("无 pkgdata 的(%d):" % len(missing_meta), missing_meta[:10])
print()
print("按体积排序的前 10:")
for f in sorted(glob.glob(OUT + "/*.deb"), key=os.path.getsize, reverse=True)[:10]:
    print("  %7.1f MB  %s" % (os.path.getsize(f) / 1048576, os.path.basename(f)))
