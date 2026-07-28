# SL1680 语音终端 · 版本与修改记录

> 记录板子配置的版本演进。每个版本对应 `backups/<日期>/` 下的一个备份包。
> 详细技术说明见 `SL1680调试总结_2026-07-23_完整版.md`。

---

## 备份记录 — **2026-07-24** 10:00（模型拉到 PC + 备份手册）

**起因**：问"板子现在的版本有备份吗、烧新镜像出问题能不能退回去"。
查下来发现一个**真缺口**：模型约 2 GB **只存在于板子的 eMMC 上**，PC 上没有副本，
而烧镜像会把 `/home` 一起覆盖 —— 一旦烧了就没了，且当初的下载 URL 没记录。

趁板子 SSH 恢复（`192.168.5.126`）立刻补上。

### 新增 `backups/models_2026-07-24/`（1.15 GB）

| 包 | 恢复到 | 解压后 |
|---|---|---|
| `voice_sv.tar.gz` | `/home/voice/sv/` | 229 MB |
| `voice_matcha.tar.gz` | `/home/voice/matcha/` | 144 MB |
| `voice_tts.tar.gz` | `/home/voice/tts/` | 234 MB |
| `voice_llm_inuse.tar.gz` | `/home/voice/llm/` | 676 MB |
| `voice_kws.tar.gz` | `/home/voice/kws/` | 5.6 MB |
| `voice_bin.tar.gz` | `/home/voice/bin/` | 224 MB |
| `voice_scripts.tar.gz` | `/home/voice/` | 17 KB |
| `etc_astra.tar.gz` | `/etc/` | 536 B（**含明文 API key**） |

**已验证**：8 个包 sha256 与板端一致，抽验可正常解压。板子上的临时打包已清理。

> `llm/` 只备了在用的那个（qwen2.5-0.5b-q8_0）。板上另有两个选型残留的 gguf，
> 当前无服务使用，未备份，省 800 MB。

### 🔴 实测澄清：7-13 镜像不能当作"当前功能的备份"

解压 `delivery_sl1680/SYNAIMG/rootfs.subimg.gz`（5.4 GB ext4）用 `debugfs` 查：

```
✗ /usr/bin/astra_voice    ✗ /usr/bin/dl_face
✗ /usr/lib/libdlsdk.so    ✗ /home/voice/
✓ /etc/asound.conf 32 字节  ← 只是 alsa-state 的占位注释
```

原因：语音终端是 7 月 18–23 日**在板子上手工装的**，从没进过任何镜像，
直到 v2.6 才第一次进 Yocto 构建。**烧回 7-13 = 回到干净底座，功能全没。**

> 第一次查的时候文件解出来是 **0 字节**（用了 `/tmp`），那批"✗ 不存在"是假阴性。
> 换到 WSL 原生盘重做才拿到可信结论 —— 顺带验证了 `debugfs` 读得动根目录，
> 排除"工具用不了"这个可能。**判据不可信时不能下结论。**

### 新增文档

`SL1680备份与恢复手册_2026-07-24.md` / `.html` —— 回答三个问题：
手上有哪些备份（5 份，镜像级 3 + 数据级 2）、区别是什么（含逐项功能对比表）、
每种怎么用（含典型场景速查表）。

### 新增工具

`tools/bget.ps1` —— 直连从板子下载（二进制安全，配合 `bput.ps1` 成对使用）

### ⚠️ 记录下来的缺口

1. **板子当前状态（v2.4）没有整机镜像备份** —— 只在 eMMC 上。
   靠"源码 + 模型备份"可重建，但不是一键回滚
2. **模型来源没记录具体 release URL** —— 所以 `models_2026-07-24/` 这份不能丢
3. **新镜像仍未在真板子上实烧验证**

> 完整对比和使用方法见 `SL1680备份与恢复手册_2026-07-24.md` / `.html`。

---

## v2.6 — **2026-07-24** 00:35（★ 出了第一个"烧完即用"的完整镜像）

`bitbake astra-media` 成功，产出 SYNAIMG 烧录包 **2.5 GB**，已复制到
`D:\Claude code\Case6_Astra\flash_image_20260723163055\`，附 `README_烧录说明.md`。

### 怎么接进镜像

- 新增 **`packagegroup-astra-terminal.bb`** —— 只拉 `astra-voice` + `dl-face`，
  具体依赖交给各自的 RDEPENDS，避免两处不同步
- **用 bbappend 挂到官方 `astra-media` 而不是新建 image** —— 同事沿用原来的
  `bitbake astra-media` 和原来的烧录流程，镜像名和产物布局都不变。
  新建 image 会换掉产物名字，烧录工具那边还得跟着改
- 可退出：`local.conf` 里写 `ASTRA_TERMINAL_PACKAGES = ""` 即回到原厂镜像

### 🔴 验收抓到四个"构建成功但功能不全"的问题

这些**全都不是构建报错**，只看"✅ 构建成功"一个都发现不了：

| # | 问题 | 后果 | 修法 |
|---|---|---|---|
| 1 | `/etc/asound.conf` 与 `alsa-state` 撞车 | `do_rootfs` 直接失败 | bbappend 删掉 alsa-state 那份 **32 字节的占位注释** |
| 2 | `dl-clock` 和 `dl-face` 都自启 | DLSDK **单进程独占**，两者抢 DL7400，表现为"屏幕黑着但服务 active" | dl-clock recipe 改 `SYSTEMD_AUTO_ENABLE = "disable"` |
| 3 | `vision-wake` 没自启 | 烧完的板子**"人走近打招呼"不工作** | 加进 `SYSTEMD_SERVICE` |
| 4 | `synap_cli_od` 依赖没声明 | 换个 image 就静默失效 | astra-voice 的 RDEPENDS 加 `synasdk-synap-runtime/models` |

> 第 3 项是我自己判断错了：原以为 vision-wake 会独占 C920 所以不该自启。
> 实际上 C920 的**视频和音频是两个独立接口，可以并存**，只有 dl_face 切 camera
> 模式时才冲突，而那时 `astra_llm.py` 会主动停掉它。板上一直是 enabled 且工作正常，
> 我却按自己的推测把它排除了 —— **应该以板子实测状态为准**。

### 🐛 我自己犯的三个错，都在验证环节被拦下

1. **`wsl_build_image.sh` 又漏了同步 layer** —— 和 v2.5 里 `wsl_sherpa_build.sh`
   是同一个错，**一天之内犯两次**。白跑一轮构建，而且"构建成功"的假象会一路骗到验收。
   已在两个脚本里都加上 `rsync --delete-excluded` 并回显实际生效值
2. **验证脚本查错目录** —— `.timer` 的软链在 `timers.target.wants`，
   不在 `multi-user.target.wants`，把正常的 `astra-cleanup.timer` 误报成"缺失"
3. **`SYSTEMD_AUTO_ENABLE:pn-dl-clock` 写在 image 的 bbappend 里不生效** ——
   这种 `:pn-` 覆盖只在 conf 文件（local.conf/layer.conf）里有效。
   已改到 dl-clock 自己的 recipe，并把"这个做法行不通"记在原处，免得下次有人再试

> **教训**：复制/交付前必须有一道独立验证，而且验证要直接读产物
> （用 `debugfs` 从 ext4 里读，不是看构建清单）。
> 如果按"构建成功"就直接交付，同事拿到的是一个**看起来正常但功能不全**的镜像。

### ✅ 复制前的实测（debugfs 直接读 ext4）

```
自启:       astra-voice / astra-translate / dl-face / vision-wake / astra-cleanup.timer
未自启(对): dl-clock / astra-mode / astra-xiaozhi
文件:       astra_voice, dl_face, astra_wait_mic.sh, libsherpa-onnx-c-api.so,
            libonnxruntime.so, libdlsdk.so, astra_llm.py, astra_translate.py,
            asound.conf, llm.conf.sample, synap_cli_od, wqy-zenhei.ttc
```

### ⚠️ 仍未闭环

1. **模型约 2GB 不在镜像里** —— 烧完要单独灌 `/home/voice/{sv,matcha,tts,llm,bin}`，
   README 里写清楚了
2. **API key** —— `/etc/astra/llm.conf.sample` 复制后填
3. **★ 没有在真板子上实烧验证过** —— 板子 SSH 自 2026-07-23 晚起不可达
   （`192.168.5.126:22` 超时）。所有验证都在镜像文件层面，
   "烧进去开机真能跑"这一步没做

---

## v2.5 — **2026-07-23** 23:50（★ sherpa-onnx 首次在 Yocto 里构建成功）

背景：同事要"烧完即用"的镜像。查下来第一道坎是 **sherpa-onnx 这个 recipe 从没编译成功过** ——
`do_configure` 就挂了，work 目录里只有源码、没有 `image/`，sstate 里零条目。
在它解决之前，"给同事一个能烧的版本"根本走不到第二步。

### 根因：不是网络，是 Yocto 自己关掉的

```
poky/meta/classes-recipe/cmake.bbclass:186   -DFETCHCONTENT_FULLY_DISCONNECTED=ON
```

Yocto 为构建可复现而硬性禁止 CMake 的 FetchContent 下载。
日志里那些 `-- Downloading xxx` **只是 sherpa 自己的 `message(STATUS)`**，
**没有任何 curl / HTTP / 超时记录** —— 这是"根本没尝试联网"的特征，
极易误判成网络不通去折腾代理。⚠️ 给 `do_configure` 加 `[network]="1"` **解决不了**。

### 修的五个问题

| # | 问题 | 修法 |
|---|---|---|
| 1 | FetchContent 被硬关，`add_subdirectory` 对着空目录报错 | 14 个第三方包走 `SRC_URI` 预取（带 sha256/`downloadfilename`/`unpack=0`）→ `do_configure:prepend` 拷进 `${S}` 命中 `possible_file_locations` → 再 `-DFETCHCONTENT_FULLY_DISCONNECTED=OFF` |
| 2 | `openfst`/`eigen` 各被要了两个不同版本 | 两个都备着 |
| 3 | espeak-ng 重设 C 标志丢了 `-Wformat`，`-Werror=format-security` 变致命 | `SECURITY_STRINGFORMAT` 保留警告只摘 `-Werror` |
| 4 | `sherpa-onnx.pc` / `cargs.h` 装错位置 → `installed but not shipped` 致命 QA | `do_install:append` 挪到标准位置 |
| 5 | 预编译 `libonnxruntime.so` 没被登记成符号版本提供者 | `RPROVIDES` 显式声明 |

**依赖有 4 层嵌套**：sherpa → kaldi-native-fbank → kissfft；sherpa → kaldi-decoder → kaldifst → openfst。
好在 CMake 的 `CMAKE_SOURCE_DIR` 始终指向顶层，嵌套层用同一招。
迭代了 5 轮，每轮 configure 只暴露下一层的第一个缺失包。

### ✅ 实测产出

```
bitbake sherpa-onnx / astra-voice / dl-face   三个全绿

sherpa-onnx_1.13.4-r0_arm64.deb
  /usr/lib/libsherpa-onnx-c-api.so    3.2 MB
  /usr/lib/libonnxruntime.so         17.4 MB
  /usr/bin/sherpa-onnx-*             20 个命令行工具(含 keyword-spotter-alsa)
  -dev 包 .so 数: 0                  ← SOLIBS 修复端到端确认

astra-voice_1.0-r0_arm64.deb   Depends: sherpa-onnx (>= 1.13.4) ✓
dl-face_1.0-r0_arm64.deb       Depends: dlsdk, ttf-wqy-zenhei ✓
astra_voice / dl_face          ELF 64-bit ARM aarch64
```

> **v2.3 那个"构建全绿、烧板才炸"的打包缺陷，此前只是理论推断，现在是实测确认修好了**：
> 运行时 deb 里 4 个 `.so` 都在，`-dev` 包一个没抢。

### 📝 顺带修正了 LICENSE

原写 `Apache-2.0` 不准确。开着 TTS 会把 **espeak-ng（GPLv3）** 编进 `libsherpa-onnx-core.so`，
GPLv3 穿透整条链路。已改为 `Apache-2.0 & GPL-3.0-or-later & MIT & BSD-3-Clause` 并在 recipe 顶部标注。

### 🔧 过程中我自己犯的两个错

- **`wsl_sherpa_build.sh` 漏了同步 recipe** —— 白跑了一整轮完整编译才发现改动没进构建树。
  已修，并在结果里加了一行回显 `SECURITY_STRINGFORMAT` 实际生效值，免得再自欺
- **`dpkg -c | head -n 20` 把 `/usr/lib` 截断了**，一度以为 `.so` 没进包。
  关键检查不能带截断

### ⚠️ 距离"烧完即用"还差

1. **没有任何 image 把这三个包拉进 rootfs** —— 全 layer 搜 `astra-voice`/`dl-face`，
   除它们自己的 recipe 目录外零引用，`local.conf` 里没有 `IMAGE_INSTALL`（易）
2. **模型约 2GB 不在 recipe 里**（`sv/` `matcha/` `tts/` `llm/`），需要分发方案（中）
3. **`llama-completion` 无 recipe**（`sherpa-onnx-*` 现在已由 recipe 产出，不用再手工编）
4. **没做整板实烧验证**

---

## v2.4 — **2026-07-23** 22:50（麦克风等待守护 + 全面功能验收）

### 🔴 修掉一个每次白烧 17 秒 CPU 的重启风暴

**现象**：本次开机 `astra-voice` 连崩 7 次，全是 `status=1/FAILURE`。

**真因不是软件 bug —— 是麦克风从 USB 上消失了**：

```
[astra] 打不开 plughw:CARD=C920,DEV=0 (capture): No such device

13:38:53  usb 1-1.3: USB disconnect, device number 5      ← C920 掉了
13:40:19  usb 1-1.3: new high-speed USB device number 6   ← 86 秒后才回来
```

C920 消失的 86 秒里，systemd 每 3 秒重拉一次，**每次都要重新加载 14-17 秒的模型再死掉**。
`1-1.3` 正是之前记录过、DisplayLink dock 在上面反复重枚举的那条总线。

**解法**：新增 `/usr/bin/astra_wait_mic.sh`，`ExecStartPre` 排在最前。两个设计要点：

1. **按卡名判断而不是卡号** —— `/proc/asound/C920` 是按名字建的，
   卡号每次开机都会变（实测这次 C920 从 card2 变成了 card0）
2. **要等到采集节点而不只是卡目录** —— 第一版只等 `/proc/asound/C920`，
   实测**不够**：卡目录先出现，`/dev/snd/pcmC<N>D0c` 要等 udev 再建一会儿，
   中间那个窗口去开会报 `No such file or directory`（报错文案和原来的 `No such device` 不同，
   正是这个差异暴露了问题）

配套：`TimeoutStartSec=180`（别让 systemd 把等待掐了）、
`StartLimitIntervalSec=300` / `StartLimitBurst=10`。
⚠️ 后两个键属于 `[Unit]` 不是 `[Service]`，放错会被静默忽略 —— 已用 `systemctl show` 验证生效。

**✅ 对抗性验证**（整设备 unbind/bind 模拟真拔插）：

| | 旧行为 | 新行为 |
|---|---|---|
| 麦克风不在时 | 崩 3 次 + 每次白加载模型 | `activating`，**加载模型 0 次、报错 0 次、NRestarts 0** |
| 麦克风插回来 | — | `[wait-mic] C920 在第 17 秒就绪` → 加载一次模型 → 开始监听，**NRestarts 全程 0** |

> **测试方法本身也踩了个坑**：第一次用**接口级** unbind/bind 模拟，
> 结果把 ALSA 留在"有卡对象但没有任何 PCM 流"的半死状态（`/proc/asound/cards` 里还列着 C920，
> 但 `/proc/asound/pcm` 里没有 `00-xx`、`/dev/snd/` 里没有 `pcmC0D0c`），
> 真拔线不会这样。改用**整设备** unbind/bind 才是等价模拟。
> 期间我一度根据残留的卡对象宣布"声卡回来了 ✓"，是**判据用浅了** —— 最硬的判据是真录一秒看 RMS。

### ✅ 全面功能验收（重启后复验）

| 功能 | 结果 |
|---|---|
| 三块屏开机自动点亮 | 2×3840×2160@60 + 1×2880×1800@60，`NRestarts=0` |
| 语音控制音量 | 「音量调到20%」→ amixer 实测变 `[20%]`，复原 30% |
| 语音切摄像头 | 屏1 切 camera + vision-wake 自动停；「关闭监控」复位并恢复 |
| 四层作答 | 音量层/设备层/云端层/搜索层全通，天气答出真实的 26℃~35℃ |
| 语音链路 | 开机欢迎语正常，麦→ASR→回复→TTS 全链路活着 |

⚠️ 这次是**软件 `reboot` 不是真断电** —— 板子重启时 DL7400 和显示器一直带电，
所以没有触发"屏自己断电后不会自动重亮"那个已知问题。真拔电源的行为仍未解决。

### 📋 同步与归档

- `meta-dlsdk/VERSION` —— 新增 layer 版本记录文件，每次同步追加，带板端 sha256
- 整层同步到 WSL 构建树 `/home/astra/sdk/meta-dlsdk`，**用真 bitbake 复验**：
  `astra-voice` 解析通过（`astra_wait_mic.sh` 已进 SRC_URI）、依赖图 3488 任务全部解析
  > 同步脚本第一版漏了 `--delete-excluded`：光 `--delete` **不会删被 `--exclude` 排除的文件**，
  > 上一轮同步进去的留档会一直赖在构建树里。已修正
- 新增 `SL1680项目总结_2026-07-23.md` / `.html` —— **项目级**总结（架构/功能/构建/未解决），
  区别于按天记录的调试总结
- 新增 `tools/brun.ps1` / `bsh.ps1` / `bput.ps1` —— 板子回家庭网络后的直连通道

### 🐛 顺带修掉的工具坑

- **`askpass_wg.cmd` 的子串匹配** —— `findstr /C:"192.168.5.1"` 会匹配上 `192.168.5.126`，
  把跳板机密码喂给板子，只报 `Permission denied` 毫无线索。改成锚定 ssh 提示里的 `@192.168.5.1's`
- **busybox 没有 `install(1)`** —— 部署脚本用了 `install -m`，全部失败，
  而我那两行"已装"是无条件 echo，等于在撒谎。改用 `cp` + `chmod` 并让每步都验证

---

## v2.3 — **2026-07-23** 18:00（Codex 审阅后的整改）

外部审阅（Codex）指出总结文档和仓库状态有一批问题，本版逐条处理。
**没有备份包**：本版只改仓库与文档，板端唯一变动是 `astra_llm.py`（见下）。

### 🔴 P0 — 仓库里还留着会让两块屏全黑的代码

板端二进制当时回滚了，**仓库源码没还原**。任何人从仓库重建镜像都会拿到危险版本。

- `meta-dlsdk/recipes-graphics/dl-face/files/dl_face.c` 从 `.pre_selfheal` 还原
  （**逐字 diff 核验**，不是看文件名：`dpaux_read`=0、`get_dpaux`=0、`show_fail`=0，
  双语字幕功能完整 `join_bilingual`=3 / `heard_src`=4）
- 危险版本改名留档 `dl_face.c.DANGEROUS_dpaux_DO_NOT_BUILD`，加显眼警告头（供复现 Issue 3）
- 加回**热插拔注册状态日志**（纯诊断）：原代码丢弃返回值，注册失败被静默吞了很久
- 重新交叉编译并部署，板上 sha256 `538511420bda…31d747`，60 秒无重启，确认无任何 AUX 自愈日志

### 🟠 P1 — 板端已验证的改动回灌仓库

仓库和板子已经严重脱节，其中 `astra-voice.service` 还停留在几天前的旧硬件配置
（`card 2` / `plughw:2,0` / 无云端 / 无 C920），照它烧一台新板子起不来。

| 文件 | 回灌前状态 |
|---|---|
| `astra-voice.service` | 旧硬件配置，完全不可用 |
| `dl-face.service` | 缺 `ExecStartPre=sleep 20`、`--fps` 还是 15 |
| `vision_wake.sh` | 缺 `sleep 0.5` 节流、缺 by-id 等待 |
| `astra_llm.py` | 四层能力（音量/设备/搜索/短指令/重扫屏）**一个都没有** |
| `astra_translate.py`、`astra-translate.service`、`asound.conf`、`astra_setvol.sh`、`astra-mode.service` | **仓库里根本不存在** |
| `silent.wav` | 不存在（`astra_setvol.sh` 靠它实例化 softvol 控件，缺了音量控制失效） |

旧版留档为 `*.repo_stale_2026-07-23`。

### 🟠 P1 — 补上两个从来就不存在的 Yocto recipe

`astra-voice` 和 `dl-face` **只有 `files/` 目录，没有 `.bb`** —— 干净镜像根本构建不出这两个程序。

- 新增 `recipes-ai/astra-voice/astra-voice_1.0.bb`
- 新增 `recipes-graphics/dl-face/dl-face_1.0.bb`
- **用真 bitbake 校验通过**（不是"写完就算"）：两个 recipe `bitbake -e` 完整展开无错，
  `bitbake -n` 依赖图 3488 个任务全部解析成功
- 校验过程抓到两个真 bug：
  1. 字体包名写错 —— 是 `ttf-wqy-zenhei` 不是 `wqy-zenhei`，`Nothing RPROVIDES` 直接报错
  2. **sherpa-onnx 打包缺陷**（更隐蔽）：它的 CMake 从不设 SOVERSION，产出无版本号的
     `libsherpa-onnx-c-api.so`；Yocto 默认把无版本号 `.so` 全丢进 `-dev` 包 ——
     **构建期一切正常，烧进板子才发现运行时库根本不在镜像里**。
     已在 `sherpa-onnx_1.13.4.bb` 加 `SOLIBS=".so"` / `FILES_SOLIBSDEV=""` 并验证生效

### 🟡 搜索失败的兜底行为

`needs_search` 拆成 `SEARCH_KEYS_HARD`（天气/股价这类答案本身就是实时数字）和
`SEARCH_KEYS_SOFT`（只是语气带"最新"）。硬实时问题搜不到时**不再回落**给云端模型，
直接说查不到。

> ⚠️ **实测修正**：审阅意见认为旧行为会让模型编造，**实测并没有** ——
> 旧版回落时 DeepSeek 自己答的是"不知道，我无法获取实时天气数据"。
> 所以这条是**加固**不是修 bug：不依赖模型自觉，且省一次云端往返。
>
> 六项测试全过：正常联网仍答出真实气温 32.9℃/26.9℃；模拟搜索失败时天气和比特币
> 都老实拒答且**不含任何数字**；软实时正常回落；本地工具层未受影响。
> 板上 `astra_llm.py` sha256 `cf65d798…5796a4`

### 🟡 文档：把"推断"和"实测"分开

初版把两者混着写，读起来都像已证实。全文加可信度标注 ✅已验证 / ⚠️高概率推断 / ❓待确认，
并重写四处：

- **C920 换 USB 口**：现象和"换口即好"是实测；"打断 isochronous"是推断，
  写明还需要 `lsusb -t` / `usbmon` 才能坐实，以及当时为什么没做
- **`prompt_tokens=21`**：单独一条不足以定案，补上 `search_result` 为空这个旁证，
  并说明无论根因如何都不影响"改用独立搜索 API"的决策
- **CPU 52.5%→21.7%**：补全测量条件（10 秒窗口、空闲待机、4 核合计、各采样 1 次），
  并写明说话时的峰值**没测过**
- **DisplayLink 报告的 libdlsdk 结论**：改为"排除了平台/libusb"（实测），
  但明确**没有**证明故障在 libdlsdk 内部 —— 前置条件没满足、该配置本就不支持、
  SDK 缺陷，三者从外部无从分辨，而这本身就是要反馈给厂商的问题

### ✅ 意外收获：一次非计划断电恢复实测

整改收尾时板子突然失联。从跳板机侧诊断确认**是板子本身离线**（ICMP 和 22 端口都不通），
而 BE3600 路由器 16ms 正常响应 —— 排除隧道问题。约 90 秒后自行回来，即板子重启过。

这比之前"主动 reboot"的验证更有说服力，因为没人为它做任何准备：

| 项 | 重启后 |
|---|---|
| 五个服务 | 全部 active |
| **两块屏** | **都点亮**：2560×1440@60（AOC）+ 2880×1800@60（便携屏），角色均为 face |
| dl-face | `NRestarts=0`，无任何 AUX 自愈日志（危险代码确实不在了） |
| 音量 | 30%（默认值持久生效） |
| `astra_llm.py` | `cf65d798…` = 本次新版，重启后仍在 |
| 欢迎语 | 正常播报（TTS 1.52s → 音频 3.13s，RTF 0.49） |

> 新增 `tools/wgjump.ps1`：板子失联时只登跳板机诊断，用来区分"隧道断了"和"板子没了"。
> 它必须用**脚本文件走 stdin**，不能传命令字符串 —— `powershell -File` 会按空格重切参数，
> 外层引号保不住，`-w` 和 `$(...)` 会被 PowerShell 自己抢去解析；
> 且重定向必须交给 `cmd.exe` 做，因为 PS 5.1 的 `Get-Content` 默认按 ANSI 解码会毁掉 UTF-8。

### 📋 新增清单文件

- `backups/2026-07-23/DEPLOY_MANIFEST.txt` — 板端↔仓库 sha256 对照，10 项全部一致
- `meta-dlsdk/recipes-ai/astra-voice/files/MODEL_MANIFEST.txt` — 约 2GB 模型的哈希清单
- `meta-dlsdk/recipes-ai/astra-voice/files/README_models.md` — 模型为什么不进 recipe、怎么补
- `meta-dlsdk/recipes-ai/astra-voice/files/llm.conf.sample` — 不含 key 的配置样例
- `tools/export_live.sh`、`tools/model_manifest.sh` — 以后随时重新导出比对

---

## v2.2 — **2026-07-23** 18:10

**备份**：`backups/2026-07-23/SL1680_backup_v2.2_2026-07-23.tar.gz`
**SHA256**：`ff191eb40b504aef0112b1724203c87d82869233e99fe01b943595500e8898e6`（板子与本地一致）

### 新增

| 类别 | 改动 | 原因 |
|---|---|---|
| 功能 | 语音指令**「重新检测屏幕」/「屏幕不亮」/「刷新屏幕」** → 重启 dl-face 重新枚举 | 便携屏断电后唯一安全的恢复方式 |
| 工具 | 三个 DLSDK 诊断工具（源码在 `meta-dlsdk/recipes-graphics/dl-face/files/`）| 见下方"重大发现" |
| 文档 | **`DisplayLink_Issue_Report_2026-07-23.md`**（中英双语）| 提交给 DisplayLink 内部 |

诊断工具：
- `dl_hptest.c` — 测 libusb 热插拔能力 + dlsdk 热插拔注册状态
- `dl_dptest.c` — 探 EDID / preferred_mode / dpaux_read / dpaux_detect
- `dl_frametest.c` — 测推帧路径 show/wait_on_show 能否区分黑屏

配套 `astra-xiaozhi/build-{hptest,dptest,frametest}-wsl.sh`
⚠️ 跑这些工具**必须先 `systemctl stop dl-face`**（dlsdk 单进程独占）

### 🔴 重大发现：DL7400 显示器断电无法自动恢复（SDK 1.5.0 / 固件 12.3.26）

四种检测手段**实测全部不可用**：

| 检测手段 | 实测结果 |
|---|---|
| `dlsdk_register_hotplug_callback` | ❌ 恒返回 `UNSUCCESSFUL(2)`、handle=NULL |
| EDID / preferred_mode / 显示器数量 | ❌ 全是缓存，屏断电了照样 SUCCESS |
| `dlsdk_dpaux_read` | ⚠️ **唯一能区分**，但推帧时轮询会让**所有输出黑屏** |
| `display_show` / `wait_on_show_for` | ❌ live 与 dead 返回**完全相同**（各 10 轮全 SUCCESS）|

两种恢复手段：

| 恢复手段 | 实测结果 |
|---|---|
| `power_on_with_mode()`（现有句柄）| ❌ 返回 SUCCESS **但屏不亮** |
| 完整重新枚举（重启进程）| ✅ **唯一有效** |

**踩过的坑**：曾按 `dpaux_read` 实现自愈并部署，两块屏都在时 90 秒零误报，**一断开屏1 就连从未断电的屏0 一起黑了**，只能重启恢复。已回滚（`/usr/bin/dl_face.pre_dpaux`）。

**曾经的错误推断**：一度以为是"libusb 平台不支持热插拔"，实测推翻——`LIBUSB_CAP_HAS_HOTPLUG=1`（支持）、libusb_init OK、systemd-udevd 在跑、加载的是新版 libusb。**根因在 libdlsdk.so 内部**。（教训：推断必须变实测再对外报告）

### 其它

- 远程操作辅助脚本从临时 scratchpad 移到项目内 **`tools/`**（曾被系统清空过一次）
- ⚠️ `.cmd` 文件里**不能写中文注释** —— cmd.exe 用 ANSI 代码页，UTF-8 中文会变成乱码命令

### 已知限制（写进 VERSION.txt）
- 便携屏断电后不会自动点亮 → 语音说「屏幕不亮」恢复
- C920 独占：dl_face camera 模式与 vision-wake 二选一
- `/tmp/astra_screen_mode.txt` 重启丢失 → 回到双表情脸（期望默认）
- 嘈杂环境需靠近麦克风（说话 RMS 与底噪重叠，根治需 KWS）

---

## v2.1 — **2026-07-23** 17:35

**备份**：`backups/2026-07-23/SL1680_backup_v2.1_2026-07-23.tar.gz`
**SHA256**：`48fb5f0263790f107fe829364da11ce91be1011a73d3cda43d03230644fd7db1`

### 修改内容

| 类别 | 文件 | 改动 | 原因 |
|---|---|---|---|
| 采音 | `astra-voice.service` | `--pad-front 0.2 → 0.5` | 实测语音片段第一段能量就高达 13604（正常应渐起），证明**开头被切**，「打开摄像头」丢成「摄像头」 |
| 采音 | `astra-voice.service` | `--min-dur 0.6 → 0.45` | 0.51 秒的短指令被整个丢弃；日志 `太轻/太短 RMS=1396<1150` 文案误导，真实原因是时长 |
| 显示 | `dl-face.service` | 新增 `ExecStartPre=/bin/sleep 20` | dl_face **只在启动那一刻枚举显示器**，冷启动时 DisplayLink 还没报全两块屏 → 只认到 1 块 |
| 指令 | `astra_llm.py` | 屏幕切换改为**【动词+名词】** | 原来只匹配"摄像头/监控"子串，ASR 误识别（如"电大监控"）会乱切屏 |
| 指令 | `astra_llm.py` | 增加**短指令精确匹配** | 上一条太严 → ASR 吃掉动词后永远不触发。用"整句去标点后精确相等"兜底 |
| 指令 | `astra_llm.py` | 切回表情脸不再单匹配「脸」字 | **「脸」是单个常用字**，误识别里出现就把摄像头切回去 —— 这是"摄像头过一会自己关"的真凶 |

### 验证结果
- 断电重启：**两块屏都点亮**（dl_face 开机后 34.5 秒启动，两块 display 全部驱动）
- 摄像头保持：90 秒 18 次采样**零跳变**
- 触发逻辑：8 条正/反例全对（「摄像头」触发、「电大监控」不触发）

### 关键参数
```
采音: min-rms 1150 / min-dur 0.45 / pad-front 0.5 / pad-back 0.2 / gain 2.0
显示: dl_face --fps 5, 开机延迟 20 秒
视觉: 采集 framerate=5/1, 检测节流 sleep 0.5
音量: 开机默认 10%
```

---

## v2.0 — 2026-07-23 15:04

**备份**：`backups/2026-07-23/SL1680_backup_2026-07-23.tar.gz`
**SHA256**：`e7be849244e22520299909d09f9e6ef864f5b890af75412c2c0ef1e3517f5bc6`

### 修改内容

| 类别 | 改动 | 说明 |
|---|---|---|
| **新功能** | **DL7400 中英对照实时字幕** | 新增 `astra_translate.py` + `astra-translate.service`；`dl_face` 重新交叉编译（读两个状态文件渲染双语）|
| **新功能** | **联网层**（智谱 web_search + DeepSeek 接地）| 实时数据问题真的联网查，严禁编造 |
| **新功能** | **本地设备工具** | 时间/日期/CPU温度/内存/运行时长/屏幕模式，全本地零成本 |
| **新功能** | **双屏分工** | 监控放屏1，对话界面（表情+字幕）永远留屏0 |
| 优化 | **CPU 52.5% → 21.7%** | `dl_face --fps 15→5`（像素搬运 311→104 MB/s）；`vision_wake.sh` 检测循环加 `sleep 0.5` 节流、采集帧率 15→5 |
| 修复 | 环境噪音误触发 | 实测办公室底噪 RMS 575~713，而门槛才 300 → `--min-rms 300→1150` |
| 修复 | `vision_wake.sh` 摄像头选择 | 加"等 30 秒 by-id + 按设备名找 C920"，避免误选到非摄像头节点 |
| 修复 | 音量控制 | dolphinasoc 是 dummy codec 无硬件音量 → ALSA `softvol` 加 `AstraVolume` 控件 |

---

## v1.x — 2026-07-22 及之前（基线）

- 本地语音助手跑通：C920 麦 → SenseVoice ASR → matcha TTS → HT517 喇叭
- LLM 从 LM Studio 切到 **DeepSeek API**（甩掉 PC 的 4090 依赖）
- `astraout` ALSA 配置（plug → 强制 48000 → hw），**绕开 22050 触发的内核 Oops**
- 视觉唤醒（NPU mobilenet 人体检测）
- 双模看门狗 `astra-mode`（云端/本地自动切换）
- **HT517 破音真凶：GAIN→GND 杜邦线断了 + Vin 只接 3.3V**（应 5V）—— 硬件问题，非软件

---

## 恢复方法

见 `backups/2026-07-23/README_恢复说明.md`，含：
- 完整恢复步骤（解包 → 还原文件 → 填密钥 → 启用服务）
- 单项回滚表（板上保留了 `.bak` / `.pre_*` 逐步回滚点）
- ⚠️ 传文件的 BOM 陷阱（二进制会被破坏）
- 交叉编译 dl_face 的方法

---

## 板上回滚点一览

| 文件 | 回到 |
|---|---|
| `/usr/bin/dl_face.bak` | 单语字幕版 |
| `/usr/bin/vision_wake.sh.pre_opt` | CPU 优化前 |
| `/etc/systemd/system/dl-face.service.pre_opt` | 优化前的 dl-face 参数 |
| `/home/voice/astra_llm.py.bak` | 加音量拦截前 |
| `/home/voice/astra_llm.py.pre_search` | 加联网层前 |
| `/home/voice/astra_llm.py.pre_device` | 加设备工具前 |
| `/home/voice/astra_llm.py.pre_dual` | 加双屏切换前 |
| `/home/voice/astra_llm.py.pre_strict` | 加严格触发前 |
| `/home/voice/astra_llm.py.pre_shortcmd` | 加短指令匹配前 |

---

## 待办（未来版本）

- [ ] **KWS 唤醒词** —— 根治嘈杂环境误触发（当前只能靠能量门槛，而用户说话 RMS 与底噪重叠）
- [ ] 板载麦 ZTS6672 驱动层问题（i2s-mic1 时钟未使能）→ 需 Synaptics FAE
- [ ] **安全**：DeepSeek key 和智谱 key 都在聊天里贴过 → **产品化前必须重新生成**
- [ ] 摄像头被占时让 vision-wake 报错而不是静默空转
- [ ] （可选）Hermes Agent 放 VPS，板子做语音/视觉前端
- [ ] （可选）AEC 回声消除
