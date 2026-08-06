#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 PCA9685/MG90S 这一轮的代码与文档打包备份到本地目录

沿用项目里 TD7800_bringup_backup_2026-07-28/ 的做法：
按类别归档 + SHA256SUMS + README，之后 scratchpad / 板端原件都可以丢。
"""
import hashlib, io, os, shutil, sys

ROOT = r"D:\Claude code\Case6_Astra"
DST  = os.path.join(ROOT, "PCA9685_MG90S_backup_2026-07-31")

# (源路径相对 ROOT, 备份内子目录, 说明)
ITEMS = [
    ("sl1680-scripts/pca9685.py",                       "board-scripts",
     "★ 板端用户态驱动（地址自动识别 / loop / stop），实测跑通"),
    ("tools/_wslout/check_pca9685.sh",                  "wsl-scripts",
     "查内核 PWM_PCA9685 配置与 i2c 总线占用"),
    ("tools/md2html.py",                                "tools",
     "md → 带样式 html 转换器（本轮新写，可复用）"),
    ("PCA9685_MG90S_接入SL1680_2026-07-31.md",          "docs",
     "接线与驱动文档（已按实测更正）"),
    ("PCA9685_MG90S_接入SL1680_2026-07-31.html",        "docs",
     "同上，html 版"),
]

# 厂商资料只记清单不复制（体积大且属第三方）
VENDOR_DIR = os.path.join(ROOT, "PCA9685 and MG90S")


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    if os.path.isdir(DST):
        shutil.rmtree(DST)
    os.makedirs(DST)

    rows, missing = [], []
    for rel, sub, desc in ITEMS:
        src = os.path.join(ROOT, rel.replace("/", os.sep))
        if not os.path.exists(src):
            missing.append(rel)
            continue
        outdir = os.path.join(DST, sub)
        os.makedirs(outdir, exist_ok=True)
        dst = os.path.join(outdir, os.path.basename(src))
        shutil.copy2(src, dst)
        rows.append((sub + "/" + os.path.basename(src), sha256(dst),
                     os.path.getsize(dst), desc))

    # 厂商资料清单
    vendor = []
    if os.path.isdir(VENDOR_DIR):
        for dirpath, _, files in os.walk(VENDOR_DIR):
            for fn in files:
                p = os.path.join(dirpath, fn)
                vendor.append((os.path.relpath(p, ROOT).replace(os.sep, "/"),
                               os.path.getsize(p)))
    vendor.sort()

    # SHA256SUMS
    with io.open(os.path.join(DST, "SHA256SUMS.txt"), "w", encoding="utf-8") as f:
        for name, h, _, _ in rows:
            f.write("%s  %s\n" % (h, name))

    # README
    with io.open(os.path.join(DST, "README_备份说明.md"), "w", encoding="utf-8") as f:
        f.write("# PCA9685 + MG90S 接入 SL1680 —— 代码与文档备份\n\n")
        f.write("**备份日期**：2026-07-31　**状态**：已实测跑通（舵机转动正常）\n\n")
        f.write("## 归档内容\n\n")
        f.write("| 文件 | 大小 | 说明 |\n|---|---:|---|\n")
        for name, _, size, desc in rows:
            f.write("| `%s` | %d B | %s |\n" % (name, size, desc))
        f.write("\n完整性校验：`SHA256SUMS.txt`\n\n")
        f.write("## 关键结论（详见 docs/ 里的文档）\n\n")
        f.write("- J32 的 I²C 已在板内过 **TXB0108**（1.8V↔3.3V），排针侧是 **3.3V 域**，"
                "PCA9685 用 3.3V 供电直接可接，**不需要额外电平转换**\n")
        f.write("- 而 J32 的 **GPIO36/37/38/39 是裸 1.8V**（没过转换）—— "
                "这正是 7-28 TD7800 复位脚踩坑的根源\n")
        f.write("- **地址冲突**：PCA9685 默认 `0x40` 被板载两颗 INA3221 占用（`0x40`/`0x41`）。"
                "用 All Call `0x70` 免焊接，或短接模块 `A1` → `0x42`\n")
        f.write("- 内核 `CONFIG_PWM_PCA9685` 未开（源码在树里），"
                "本方案走**用户态** `/dev/i2c-0`，不重编不重启\n")
        f.write("- 舵机 **V+ 必须外部供电**；PCA9685 的 **VCC 只能接 3.3V**"
                "（接 5V 会经模块上拉灌进 TXB0108 的 3.3V 侧）\n\n")
        f.write("## 实测数据\n\n")
        f.write("```\n")
        f.write("i2c-0:  0x2c 触摸(UU)  0x40/0x41 INA3221(UU)  0x45 遗留(UU)  0x70 PCA9685 All Call\n")
        f.write("init :  PRE_SCALE=121 -> 50.03 Hz (19.99 ms)  1 count = 4.88 us\n")
        f.write("CH0  :  ON=0 OFF=307 -> 1498 us（目标 1500）\n")
        f.write("loop :  OFF=512 -> 2499us  /  OFF=102 -> 498us  交替，舵机转动正常\n")
        f.write("电源 :  舵机动作 12s 期间 PWR_3V3 跌 0.24%，VDDM_1V8 跌 0.00%\n")
        f.write("```\n\n")
        f.write("## 厂商原始资料（未复制，体积大且属第三方）\n\n")
        f.write("留在 `PCA9685 and MG90S/`，共 **%d 个文件**。按目录汇总：\n\n" % len(vendor))
        # 按第二级目录归并，避免逐个列出几百行
        groups = {}
        for p, size in vendor:
            parts = p.split("/")
            key = "/".join(parts[:3]) if len(parts) > 3 else "/".join(parts[:2])
            g = groups.setdefault(key, [0, 0])
            g[0] += 1
            g[1] += size
        f.write("| 目录 | 文件数 | 合计 |\n|---|---:|---:|\n")
        for k in sorted(groups):
            n, sz = groups[k]
            f.write("| `%s` | %d | %.1f MB |\n" % (k, n, sz / 1048576.0))
        f.write("\n**其中真正用得上的几份：**\n\n")
        KEY = ["芯片手册", "原理图", "使用说明", "引脚图"]
        for p, size in vendor:
            if any(k in p for k in KEY):
                f.write("- `%s`（%.1f KB）\n" % (p, size / 1024.0))
        f.write("\n> `MG90S/舵机控制例程/` 下是一整套 STM32F103 + Arduino 例程"
                "（含标准外设库），本项目用不到，仅作参考。\n")
        f.write("\n---\n\n")
        f.write("恢复方法：把 `board-scripts/pca9685.py` 传到板子 `/home/voice/` 即可，"
                "无其它依赖（板上 python3 3.12.9 + numpy 已有，脚本本身只用 ctypes 和标准库）。\n")

    print("备份完成: %s" % DST)
    print()
    for name, h, size, _ in rows:
        print("  %-42s %7d B  %s" % (name, size, h[:16] + "..."))
    if missing:
        print()
        print("  ⚠ 缺失(未备份): " + ", ".join(missing))
    print()
    print("  厂商资料清单 %d 项（未复制，只记在 README）" % len(vendor))


if __name__ == "__main__":
    main()
