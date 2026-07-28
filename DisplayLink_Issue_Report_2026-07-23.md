# DisplayLink DL-7400 / DLSDK Issue Report

**Date:** 2026-07-23
**Reporter:** SL1680 (Synaptics Astra "Dolphin" RDK) integration team
**Severity:** Medium-High — blocks unattended display recovery

---

## Environment / 环境

| Item | Value |
|---|---|
| Dock | DisplayLink DL-7400 (`Redwood-8Gb Video Dock`, USB `17e9:7000`) |
| Device firmware | **12.3.26** (via `dlsdk_device_firmware_version()`) |
| DLSDK version | **1.5.0.post120+gf837c2af6ff.build156** (via `dlsdk_version()`) |
| Host | Synaptics SL1680 (quad Cortex-A73), Yocto, kernel 6.12.62, aarch64 |
| libusb | `/usr/lib/libusb-1.0.so.0` (472856 bytes, 2026-07-17) |
| Displays | #0 AOC Q2790R3 2560x1440@60, #1 portable 2880x1800@60 |

---

## Issue 1 — `dlsdk_register_hotplug_callback()` always fails

### Observed / 现象

```
dlsdk_register_hotplug_callback(cb, NULL, &handle)
  -> returns DLSDK_UNSUCCESSFUL (2), handle = NULL
```

Reproduced **both** before and after `dlsdk_get_devices()`:

```
SDK version: 1.5.0.post120+gf837c2af6ff.build156
  register (before get_devices): status=2 handle=NULL
  get_devices: status=0 devices=1
  firmware: 12.3.26
  register (after get_devices):  status=2 handle=NULL
```

Consequently `DLSDK_HOTPLUG_EVENT_DISPLAY_ARRIVED` / `DISPLAY_REMOVED` are **never delivered**
(0 events over months of continuous operation).

### Impact / 影响

A monitor that is powered off and back on at a dock port is never detected and never re-lit.
Our application has no way to know a display went away or came back.
*(Note: our original code discarded the return value, so this failure was silent for months.
We recommend the API docs stress checking it.)*

### What we ruled out / 已排除的可能

We initially suspected a libusb platform limitation. **Measured, and it is not:**

```
libusb_init: 0 (OK)
LIBUSB_CAP_HAS_CAPABILITY                = 1
LIBUSB_CAP_HAS_HOTPLUG                   = 1     <-- supported
LIBUSB_CAP_HAS_HID_ACCESS                = 65536
LIBUSB_CAP_SUPPORTS_DETACH_KERNEL_DRIVER = 131072
systemd-udevd running (pid 394)
```

- libusb hotplug capability is **present**.
- The process loads `/usr/lib/libusb-1.0.so.0` (verified via `/proc/<pid>/maps`), which exports
  3 `libusb_hotplug_*` symbols.
- An older `libusb-1.0.so.0.4.0` (2018) also exists on the image but is **not** the one loaded.

`libdlsdk.so` references `libusb_hotplug_register_callback` / `libusb_hotplug_deregister_callback`
and contains a `BdpHotplugDebouncer` class, so the machinery is present — but registration still
returns `DLSDK_UNSUCCESSFUL`.

**What this establishes / 这些证据能证明什么**

The original suspicion — that the platform lacks USB hotplug support — is **ruled out by
measurement**. libusb reports `LIBUSB_CAP_HAS_HOTPLUG = 1`, the loaded library exports the
hotplug symbols, and udev is running.
最初怀疑"平台不支持 USB 热插拔"，**已被实测排除**。

**What it does not establish / 不能证明什么**

We have *not* isolated the failure to a defect in `libdlsdk.so`. Ruling out one cause does not
identify the remaining one. Still open, and not distinguishable from the outside:

- a **precondition we are not meeting** (config field, init order, permissions, a required
  udev rule or device-node access) that the SDK correctly rejects;
- an **unsupported configuration** rather than a bug — e.g. hotplug not implemented for this
  transport or for `embeddedMode`;
- a genuine defect in the SDK.

Since `DLSDK_UNSUCCESSFUL` is a generic status with no accompanying diagnostic, an integrator
cannot tell these apart. That inability is itself the practical problem, and it is why
question 4 below matters as much as question 1.

我们**没有**证明故障出在 `libdlsdk.so` 内部 —— 排除了一个原因不等于锁定了另一个。
仍无法区分：我们没满足某个前置条件、该配置本就不支持、还是 SDK 缺陷。
`DLSDK_UNSUCCESSFUL` 是一个不带任何诊断信息的通用状态码，集成方从外部无从分辨 ——
**这本身就是最实际的问题**，所以下面第 4 问和第 1 问同样重要。

### Questions for DisplayLink / 请教

1. Under what conditions does `dlsdk_register_hotplug_callback()` return `DLSDK_UNSUCCESSFUL`?
2. Is hotplug supported in **embedded mode** (`dlsdk_config.embeddedMode`)? We pass `embeddedMode = 0`.
3. Is there a build flag / runtime prerequisite for hotplug in 1.5.0 that we are missing?
4. Can the SDK expose a more specific status (e.g. `NOT_IMPLEMENTED`) so integrators can tell
   "unsupported" from "transient failure"?

---

## Issue 2 — Display state APIs return **cached** values, so they cannot detect monitor loss

This is arguably the more impactful finding for integrators.

### Observed / 现象

With display #1 (portable monitor) **physically powered off and back on** — its DP link never
retrained, screen stayed dark — we probed every display-state API:

| API | Display #0 (healthy) | Display #1 (link down) | Useful for presence? |
|---|---|---|---|
| `dlsdk_device_get_displays()` count | 2 | 2 (unchanged) | ❌ no |
| `dlsdk_display_edid()` | SUCCESS, len=256 | **SUCCESS, len=256** | ❌ no — cached |
| `dlsdk_display_preferred_mode()` | SUCCESS 2560x1440@60 | **SUCCESS 2880x1800@60** | ❌ no — cached |
| `dlsdk_dpaux_detect()` | SUCCESS | **SUCCESS** | ❌ no — does not discriminate |
| **`dlsdk_dpaux_read(0x0000)`** (DPCD_REV) | **`AuxAck`**, 0x12 | **`AuxError`**, 0x00 | ✅ **yes** |
| **`dlsdk_dpaux_read(0x0200)`** (SINK_COUNT) | **`AuxAck`**, 0x41 | **`AuxError`**, 0x00 | ✅ **yes** |
| `dlsdk_display_show()` | SUCCESS | SUCCESS (frames go nowhere) | ❌ no |

### Impact / 影响

- `dlsdk_display_edid()` and `dlsdk_display_preferred_mode()` returning SUCCESS for a monitor that
  is physically absent is **misleading**. Any integrator using them as a presence check gets a
  false positive.
- The display count from `dlsdk_device_get_displays()` does **not** change, so polling enumeration
  does not help either.
- `dlsdk_dpaux_detect()` — documented as *"detect if a monitor is connected to the DP AUX channel,
  and force training"* — returns `SUCCESS` for a monitor that is demonstrably not connected, and
  did **not** retrain the link. The name and doc suggest it should do exactly what we need.
- **Only `dlsdk_dpaux_read()` reflects physical reality.** We are building our recovery logic on it.

### Questions for DisplayLink / 请教

1. Is `dlsdk_display_edid()` intentionally served from cache? If so, is there a way to force a
   re-read from the sink?
2. What is `dlsdk_dpaux_detect()` expected to return when no sink is present? Should it not
   return an error, or at least surface `AuxDetached`?
3. Is there an intended/supported API to answer **"is a monitor currently attached to output N?"**
   We did not find one, and `AuxDetached (0x12)` in `enum AuxStatus` suggests the information
   exists at the AUX layer.
4. Is there a supported way to **force DP link retraining** after a sink returns, short of
   tearing down and re-enumerating the whole SDK session?

---

---

## Issue 3 — `dlsdk_dpaux_read()` on a **detached** sink blanks *all* outputs on the device

This is the most serious of the three, and it closed off our only remaining workaround.

### Observed / 现象

Having established that `dlsdk_dpaux_read()` is the only API that reflects physical presence
(Issue 2), we implemented recovery on top of it:

- every 10 s, per display, one `dlsdk_dpaux_read(aux, 0x0000, &rev, 1)` (DPCD_REV)
- on `AuxError -> AuxAck` transition, `dlsdk_display_power_on_with_mode()` to re-light in place

With **both** monitors connected this ran cleanly: 9 probe cycles over 90 s, no misfires, no
restarts, both displays streaming normally.

We then physically **powered off display #1**. The probe correctly detected it:

```
[dl_face] display 1 link down (AUX status=0x11 AuxError), waiting for it to return
```

**Then both displays went dark — including display #0, which was never powered off and was
streaming normally.** Recovery required restarting our process (which re-enumerates and re-lights
both).

### Analysis / 分析

The only difference from the working case is that AUX transactions were now being issued to a
**detached** sink, concurrently with `dlsdk_display_show()` calls from GStreamer streaming threads
targeting *both* displays on the same device.

Our working hypothesis is that an AUX transaction to a detached sink holds a device-level lock (or
otherwise stalls the device's frame path) long enough to starve `dlsdk_display_show()` for every
output on that device. Notably the header documents `dlsdk_dpaux_read()` as waiting "up to 400us"
for a response, which should be harmless — so the observed behaviour does not match the documented
timing.

Important: the same `dlsdk_dpaux_read()` call against the same detached sink returns `AuxError`
**quickly and harmlessly** when run from a standalone tool with no other DLSDK activity. The
failure only appears under concurrent streaming.

### Impact / 影响

Combined with Issues 1 and 2, there is currently **no safe way for an application to detect that a
monitor has been unplugged/powered off and recover automatically**:

- hotplug callbacks cannot be registered (Issue 1)
- EDID / preferred_mode / display count are cached and report the monitor as present (Issue 2)
- the one API that does reflect reality cannot be polled safely while streaming (Issue 3)

### Questions for DisplayLink / 请教

1. Is `dlsdk_dpaux_read()` safe to call from a different thread while `dlsdk_display_show()` is
   active on the same device? Is there a documented locking/threading model for the SDK?
2. Is there a bounded-timeout or non-blocking variant of the AUX transaction?
3. Given Issues 1–3 together, **what is the officially recommended way for an embedded application
   to detect monitor removal/return and recover?** This is our core question.

---

## Issue 4 — The frame path cannot detect it either, and `power_on_with_mode()` cannot recover it

After Issue 3 closed off AUX polling, we tested the one remaining candidate: the **existing frame
path**. `dlsdk_display_show()` / `dlsdk_display_wait_on_show_for()` are already called every frame,
so checking their status adds no new SDK calls and no new lock contention.

### Observed / 现象

With display #1 physically powered off (dark) and display #0 healthy, pushing alternating
red/blue full-screen frames to both, 10 rounds each:

```
                display_show      wait_on_show_for(1000ms)
display #0      SUCCESS  x10      SUCCESS  x10
display #1      SUCCESS  x10      SUCCESS  x10      <-- identical
```

**The frame path reports SUCCESS for a monitor that is physically dark.** `wait_on_show_for()` does
not time out. There is no observable difference between a live and a dead output.

Simultaneously, on the same displays: `dpaux_read(0x0000)` → `AuxAck`/0x12 on #0 vs
`AuxError`/0x00 on #1. So the device *knows*; the frame API just does not surface it.

### Also observed — recovery / 恢复方面

```
display #1 (dark)   dlsdk_display_power_on_with_mode(...)  ->  SUCCESS
                    ... monitor stays dark
```

`power_on_with_mode()` returns `SUCCESS` on an existing handle for a display whose sink is gone,
but **does not re-establish the link**. The only thing that actually re-lights the monitor is a
full teardown + `dlsdk_get_devices()` / `dlsdk_device_get_displays()` re-enumeration (i.e. new
display handles).

### Impact / 影响

Combined with Issues 1–3, **there is no safe automatic recovery path at all** in SDK 1.5.0:

| Detection method | Result |
|---|---|
| hotplug callback | cannot register (Issue 1) |
| EDID / preferred_mode / display count | cached, reports present (Issue 2) |
| `dpaux_read` | works, but blanks all outputs when polled during streaming (Issue 3) |
| `display_show` / `wait_on_show_for` | identical SUCCESS for live and dead outputs (Issue 4) |

| Recovery method | Result |
|---|---|
| `power_on_with_mode()` on existing handle | returns SUCCESS, monitor stays dark |
| full SDK re-enumeration (restart process) | ✅ works |

We are therefore forced into operator-triggered recovery.

### Questions for DisplayLink / 请教

1. Should `dlsdk_display_show()` / `dlsdk_display_wait_on_show_for()` surface a sink-loss condition?
   `DLSDK_UNSUCCESSFUL_MONITOR_OFF` exists in `dlsdk_status` — under what circumstances is it returned?
2. Is `power_on_with_mode()` expected to re-train the link on an existing display handle? If not,
   is there an API to force re-establishment without full re-enumeration?

---

## Our current workaround / 我们目前的规避方案

Because none of the above is safe, we fell back to an **operator-triggered** recovery: a voice
command that restarts our rendering process, which re-enumerates and re-lights all displays. It
works reliably, but it is manual — the device cannot recover unattended.

We would much rather use a supported hotplug/presence API — hence this report.

---

## Reproduction / 复现方法

Minimal test programs are available (`dl_hptest.c`, `dl_dptest.c`). Both link only against
`libdlsdk.so` + `libusb-1.0`.

1. `dl_hptest` — calls `libusb_has_capability()` then `dlsdk_register_hotplug_callback()` twice
   (before and after `dlsdk_get_devices()`), printing all status codes.
2. `dl_dptest` — enumerates displays and, for each, prints `edid` / `preferred_mode` /
   `dpaux_read(DPCD_REV)` / `dpaux_read(SINK_COUNT)` / `dpaux_detect` results.
   Run it with a monitor powered on, then powered off, and compare.

Note: the SDK is single-process-exclusive — stop any other DLSDK application first.

---

# 中文摘要

## 问题一：`dlsdk_register_hotplug_callback()` 恒定失败

在 SL1680 上，无论在 `dlsdk_get_devices()` **之前还是之后**调用，都返回
`DLSDK_UNSUCCESSFUL(2)`、handle 为 NULL。因此 `DISPLAY_ARRIVED` / `DISPLAY_REMOVED`
事件**从未送达**（连续运行数月，0 次触发）。后果是：**dock 端口上的显示器断电再上电，
应用完全无法感知，屏幕也不会重新点亮。**

**已排除 libusb 与平台因素**（这点很重要，避免误导排查方向）：
- `libusb_has_capability(LIBUSB_CAP_HAS_HOTPLUG)` 返回 **1（支持）**
- `libusb_init()` 成功，`systemd-udevd` 正常运行
- 进程实际加载的是新版 `/usr/lib/libusb-1.0.so.0`（经 `/proc/<pid>/maps` 确认），
  它导出了 3 个 `libusb_hotplug_*` 符号
- 镜像里虽然还有个 2018 年的 `libusb-1.0.so.0.4.0`，但**未被加载**

`libdlsdk.so` 内部确实引用了 `libusb_hotplug_register_callback` 并含 `BdpHotplugDebouncer` 类，
机制是存在的，但注册就是失败。**结论：问题在 libdlsdk.so 内部。**

**想请教：** 什么条件下会返回 `UNSUCCESSFUL`？embedded mode 是否支持热插拔？
1.5.0 是否有我们遗漏的编译开关或运行时前提？能否返回更具体的状态码
（如 `NOT_IMPLEMENTED`）以便区分"不支持"和"临时失败"？

## 问题二：显示器状态类 API 返回**缓存值**，无法用于在线检测

把便携屏物理断电再上电（链路未重新训练、屏幕保持黑屏），实测各 API：

- `dlsdk_display_edid()` → 仍返回 **SUCCESS，256 字节**（缓存，误导）
- `dlsdk_display_preferred_mode()` → 仍返回 **SUCCESS**（缓存，误导）
- `dlsdk_device_get_displays()` 数量 → **不变**（轮询枚举无效）
- `dlsdk_dpaux_detect()` → **SUCCESS**（不区分在与不在，也没有重新训练链路）
- **`dlsdk_dpaux_read()` → 正常屏 `AuxAck`，掉线屏 `AuxError`** ✅ **只有它反映物理现实**

**想请教：** EDID 是有意走缓存吗？有没有强制重读的办法？`dpaux_detect` 在无 sink 时
预期返回什么？有没有官方的"输出 N 上当前是否接着显示器"查询接口？
有没有在 sink 回来后**强制 DP 链路重训**的支持方式（不必推倒整个 SDK 会话重来）？

## 问题三：对**已断开**的 sink 调 `dlsdk_dpaux_read()`，会让该 device 上**所有**输出黑屏

这条最严重，它堵死了我们最后一条规避路线。

确认 `dpaux_read` 是唯一能反映物理现实的接口后，我们据此实现了自愈：每 10 秒对每块屏做
一次 `dlsdk_dpaux_read(0x0000)`，发现 `AuxError -> AuxAck`（屏回来了）就
`power_on_with_mode` 原地点亮。

**两块屏都在时运行完全正常**：90 秒 9 次探测，零误报零重启，两块屏推帧正常。

**然后我们物理断开屏1 的电源**，探测正确识别到了：
```
[dl_face] 屏 1 显示器掉线(AUX status=0x11 AuxError)，等它回来
```
**紧接着两块屏全黑了 —— 包括从未断电、一直正常推帧的屏0。** 只能重启进程才恢复。

**分析**：与正常情况唯一的差别，是此时 AUX 事务打向了一个**已断开的 sink**，同时
GStreamer 线程正在对同一 device 的**两块屏**调用 `dlsdk_display_show()`。我们推测
对断开 sink 的 AUX 事务会长时间持有 device 级的锁（或以其它方式阻塞帧路径），
把该 device 上所有输出的推帧饿死。注意头文件写的是 `dpaux_read` "最多等 400us"，
按此不该有影响 —— **实测行为与文档时序不符**。

**重要**：同样的 `dpaux_read`、同样的断开 sink，在**没有其它 DLSDK 活动**的独立工具里调用，
会**快速且无害地**返回 `AuxError`。**只有在并发推帧时才会出事。**

**影响**：三个问题叠加，**目前应用没有任何安全的办法自动检测显示器拔除/断电并恢复**：
- 热插拔回调注册不了（问题一）
- EDID / preferred_mode / 显示器数量都是缓存，断电了还报"在"（问题二）
- 唯一反映现实的接口，在推帧时不能安全轮询（问题三）

**想请教：**
1. `dlsdk_dpaux_read()` 能否在其它线程于同一 device 上 `display_show()` 时并发调用？
   SDK 有没有文档化的锁/线程模型？
2. AUX 事务有没有可设超时或非阻塞的变体？
3. 综合问题一~三，**嵌入式应用检测显示器移除/回归并恢复，官方推荐的做法到底是什么？**
   这是我们最核心的疑问。

## 问题四：推帧路径同样检测不到，且 `power_on_with_mode()` 也恢复不了

问题三堵死 AUX 轮询后，我们测了最后一个候选：**已有的推帧路径**。
`display_show` / `wait_on_show_for` 本来每帧都在调，检查返回值不增加任何 SDK 调用和锁竞争。

**实测**（屏1 物理断电黑屏、屏0 正常，交替推红/蓝全屏，各 10 轮）：
```
              display_show      wait_on_show_for(1000ms)
屏0            SUCCESS x10       SUCCESS x10
屏1            SUCCESS x10       SUCCESS x10      ← 完全一样
```
**推帧路径对一块物理黑屏的显示器全程返回 SUCCESS**，`wait_on_show_for` 也不超时，
live 和 dead 输出**毫无差别**。而同一时刻 `dpaux_read` 明确区分（屏0 `AuxAck`/0x12、
屏1 `AuxError`/0x00）——**设备是知道的，只是帧接口不暴露**。

**恢复方面同样实测**：
```
屏1(黑) dlsdk_display_power_on_with_mode(...) -> SUCCESS ，但屏依然不亮
```
`power_on_with_mode()` 在 sink 已丢失的现有句柄上返回 SUCCESS，**但不会重建链路**。
真正能点亮的只有**完整推倒重来 + 重新枚举**（拿到全新的 display 句柄）。

**综合问题一~四，SDK 1.5.0 下不存在任何安全的自动恢复路径：**

| 检测手段 | 结果 |
|---|---|
| 热插拔回调 | 注册失败（问题一）|
| EDID / preferred_mode / 显示器数量 | 缓存，报"在"（问题二）|
| `dpaux_read` | 有效，但推帧时轮询会让所有输出黑屏（问题三）|
| `display_show` / `wait_on_show_for` | live 与 dead 返回完全相同（问题四）|

| 恢复手段 | 结果 |
|---|---|
| 现有句柄上 `power_on_with_mode()` | 返回 SUCCESS，屏依然黑 |
| 完整重新枚举（重启进程）| ✅ 唯一有效 |

**想请教：** `display_show`/`wait_on_show_for` 是否应该反映 sink 丢失？
`dlsdk_status` 里有 `DLSDK_UNSUCCESSFUL_MONITOR_OFF`，它在什么情况下返回？
`power_on_with_mode()` 在现有句柄上是否应当重新训练链路？若不应，有没有不做
完整重新枚举就能强制重建链路的接口？

## 我们目前的规避方案

由于上述方式都不安全，我们退回到**人工触发**恢复：用一条语音指令重启渲染进程，
由它重新枚举并点亮所有显示器。这个方式可靠，但是**手动的** —— 设备无法无人值守自动恢复。

我们更希望使用官方支持的热插拔/在线检测接口，因此提交此报告。
