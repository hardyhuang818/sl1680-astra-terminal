#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把本项目的中文技术文档 md 转成带样式的单文件 html

用法:  python tools/md2html.py <输入.md> [输出.html] [--title "标题"] [--sub "副标题"]

样式与项目里其它文档保持一致：深蓝渐变页头、卡片式章节、可横向滚动的表格、
深色代码块、blockquote 变成提示框。★ 开头的表格单元格会高亮（本项目用 ★ 标"实测修正"）。
"""
import io, os, re, sys
import markdown

CSS = """
:root{
  --bg:#f6f7fa; --card:#fff; --ink:#181b21; --sub:#576070;
  --line:#e2e6ee; --accent:#0b6efd; --teal:#00a3a3;
  --good:#0f7b40; --goodbg:#eaf7f0; --bad:#b91c1c; --badbg:#fdeceb;
  --warn:#b45309; --warnbg:#fff8e6; --codebg:#0d1b2e; --codefg:#d8e4f5;
}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);
  font-family:"Microsoft YaHei","PingFang SC","Hiragino Sans GB","Source Han Sans SC",-apple-system,"Segoe UI",sans-serif;
  line-height:1.8;font-size:16px}
.wrap{max-width:1080px;margin:0 auto;padding:30px 20px 80px}
header.hero{background:linear-gradient(135deg,#07204a 0%,#0b6efd 58%,#00a3a3 100%);
  color:#fff;border-radius:14px;padding:34px 32px;margin-bottom:20px;
  box-shadow:0 10px 30px rgba(7,32,74,.2)}
header.hero .kicker{font-size:13px;letter-spacing:.14em;opacity:.85;text-transform:uppercase}
header.hero h1{margin:10px 0 8px;font-size:29px;line-height:1.35;font-weight:700}
header.hero .meta{font-size:14px;opacity:.93;border-top:1px solid rgba(255,255,255,.28);
  padding-top:12px;margin-top:14px}
main{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:8px 32px 30px}
h2{font-size:21px;margin:34px 0 12px;color:#07204a;font-weight:700;
   padding-top:18px;border-top:1px solid var(--line)}
main > h2:first-of-type{border-top:none;padding-top:6px;margin-top:14px}
h3{font-size:16.5px;margin:24px 0 8px;color:#0d2a52}
h4{font-size:15px;margin:18px 0 6px;color:#0d2a52}
p{margin:10px 0}
ul,ol{margin:10px 0;padding-left:26px}
li{margin:6px 0}
a{color:var(--accent)}
code{background:#eef1f6;border-radius:4px;padding:1px 6px;font-size:14px;
  font-family:"Cascadia Mono",Consolas,"Courier New",monospace;color:#0a3d62;
  word-break:break-word}
pre{background:var(--codebg);color:var(--codefg);border-radius:10px;padding:16px 18px;
  overflow-x:auto;font-size:13.5px;line-height:1.7;margin:14px 0;
  font-family:"Cascadia Mono",Consolas,"Courier New",monospace}
pre code{background:none;color:inherit;padding:0;font-size:inherit;word-break:normal}
table{width:100%;border-collapse:collapse;margin:14px 0;font-size:14.5px;
  display:block;overflow-x:auto}
th,td{border:1px solid var(--line);padding:10px 12px;text-align:left;vertical-align:top}
th{background:#eef3fb;color:#07204a;font-weight:600;white-space:nowrap}
tbody tr:nth-child(even){background:#fafbfd}
td.star{background:#fff8e6}
blockquote{background:var(--warnbg);border:1px solid #f0d9a0;border-left:4px solid var(--warn);
  border-radius:8px;padding:12px 18px;margin:16px 0;color:#5a4a20}
blockquote p{margin:6px 0}
blockquote code{background:#f6ecd5;color:#6b5320}
hr{border:none;border-top:1px solid var(--line);margin:26px 0}
strong{color:#0b2b5b}
footer{margin-top:22px;padding:18px 24px;background:#fff;border:1px solid var(--line);
  border-radius:12px;font-size:13.5px;color:var(--sub)}
@media (max-width:640px){
  .wrap{padding:16px 12px 60px}
  header.hero{padding:22px 18px} header.hero h1{font-size:21px}
  main{padding:6px 16px 22px}
}
@media print{
  body{background:#fff} main,footer,blockquote,table{break-inside:avoid}
  header.hero{box-shadow:none}
  pre{background:#f4f6fa;color:#12233d;border:1px solid #dde3ec}
}
"""

TPL = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>%(title)s</title>
<style>%(css)s</style>
</head>
<body>
<div class="wrap">
<header class="hero">
  <div class="kicker">%(kicker)s</div>
  <h1>%(title)s</h1>
  <div class="meta">%(meta)s</div>
</header>
<main>
%(body)s
</main>
<footer>%(footer)s</footer>
</div>
</body>
</html>
"""


def split_front(md):
    """把 md 的一级标题和紧随其后的元信息行抽出来当页头"""
    lines = md.splitlines()
    title, meta, i = None, [], 0
    while i < len(lines):
        s = lines[i].strip()
        if title is None:
            if s.startswith("# "):
                title = s[2:].strip()
                i += 1
                continue
            if not s:
                i += 1
                continue
            break
        if s.startswith("---"):
            i += 1
            break
        if s:
            meta.append(s)
        i += 1
    return title, meta, "\n".join(lines[i:])


def main():
    argv = sys.argv[1:]
    a, opt, skip = [], {}, False
    for j, x in enumerate(argv):
        if skip:                      # 上一个是选项名，这个是它的值
            skip = False
            continue
        if x in ("--title", "--sub", "--kicker"):
            if j + 1 < len(argv):
                opt[x[2:]] = argv[j + 1]
                skip = True           # 别把值也当成位置参数
            continue
        if x.startswith("--"):
            continue
        a.append(x)
    if not a:
        print(__doc__)
        sys.exit(1)
    src = a[0]
    dst = a[1] if len(a) > 1 else os.path.splitext(src)[0] + ".html"

    md_text = io.open(src, encoding="utf-8").read()
    title, meta_lines, rest = split_front(md_text)
    title = opt.get("title") or title or os.path.basename(src)

    html = markdown.markdown(
        rest,
        extensions=["tables", "fenced_code", "sane_lists", "attr_list"],
        output_format="html5",
    )

    # ★ 单元格高亮：本项目用 ★ 标"实测后修正"的条目
    html = re.sub(r"<td>(\s*(?:<[^>]+>\s*)*★)", r'<td class="star">\1', html)

    meta_html = "<br>".join(
        markdown.markdown(m, extensions=["tables"]).replace("<p>", "").replace("</p>", "")
        for m in meta_lines) or opt.get("sub", "")

    out = TPL % {
        "title": title,
        "css": CSS,
        "kicker": opt.get("kicker", "SL1680 · 技术文档"),
        "meta": meta_html,
        "body": html,
        "footer": "由 <code>%s</code> 生成 · 源文件 <code>%s</code>" %
                  (os.path.basename(__file__), os.path.basename(src)),
    }
    io.open(dst, "w", encoding="utf-8").write(out)
    print("已生成 %s  (%.1f KB)" % (dst, os.path.getsize(dst) / 1024.0))


if __name__ == "__main__":
    main()
