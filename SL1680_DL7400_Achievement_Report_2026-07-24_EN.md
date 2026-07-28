# SL1680 + DL7400 Project Achievement Report

**Date**: 2026-07-24　　**Platform**: Synaptics SL1680 (Dolphin RDK) + DisplayLink DL7400 EVK
**All figures are from measurements on real hardware**, not datasheet estimates.

---

## 1 · Executive Summary

We built a **local voice-AI terminal with multi-display output** on the Synaptics SL1680.
Current status:

| Capability | Result |
|---|---|
| **Multi-display** | ✅ **4 displays verified running concurrently**, mixed resolutions, no kernel driver needed |
| **Voice interaction** | ✅ On-device ASR + TTS, cloud LLM, 5–6 s end-to-end |
| **Vision wake** | ✅ NPU person detection — greets automatically when someone approaches |
| **Camera to display** | ✅ Live C920 feed can be switched to any display by voice |
| **Productization readiness** | ⚠️ Suitable for **digital signage / dashboards / interactive kiosks**; ❌ not a video wall |

**One-line positioning**: this is a **multi-display content presentation and voice interaction terminal**,
not a video playback device.

---

## 2 · Test Conditions (Hardware and Software Basis)

**This system was built with very low resource investment**: one borrowed development board,
one borrowed EVK, a few self-purchased accessories, and software based on the Synaptics
open-source SDK published on GitHub.

### 2.1 Hardware

| Item | Model / Spec | Qty | Source |
|---|---|---|---|
| **Main board** | Synaptics SL1680 Astra (Dolphin RDK)<br>4×Cortex-A73 + NPU, 4 GB LPDDR4 | 1 | **Borrowed** (formerly a Yealink test board; factory image retained for restore) |
| **Multi-display** | DisplayLink DL7400 EVK (Redwood-8Gb Video Dock)<br>USB `17e9:7000`, firmware 12.3.26 | 1 | **Borrowed** |
| Camera + microphone | Logitech C920 (one USB device exposing both audio and video interfaces) | 1 | **Purchased** |
| Amplifier | HT517 (I2S digital amplifier) | 1 | Purchased |
| Speaker | Matching speaker | 1 | Purchased |
| **Displays ×4** | Sculptor portable 2880×1800 @60 (HDMI)<br>Redmi 27 NU 3840×2160 @60<br>Mi Monitor 3840×2160 @60<br>Samsung S24D390 1920×1080 @60 | 4 | **Self-owned** |

> **Not used**: GPU, external PC, dedicated AI accelerator card.
> The entire voice AI stack runs on the SL1680's own CPU and NPU.

### 2.2 Software Basis

| Component | Source | License | Notes |
|---|---|---|---|
| **Astra Yocto SDK** | **GitHub `synaptics-astra` (open source)** | Open source | Branch `scarthgap_6.12_v2.3.0`, commit `a0344af` (2026-04-14) |
| Yocto / Poky | scarthgap 5.0.9 | Open source | Kernel 6.12.62 |
| **DLSDK** | ⚠️ **Not part of the open-source SDK** | **Closed** (`LICENSE = CLOSED`) | Pre-built `libdlsdk.so` + firmware package supplied separately by Synaptics/DisplayLink |
| sherpa-onnx | GitHub k2-fsa | Apache-2.0 | Speech recognition / synthesis inference framework |
| SenseVoice / matcha / silero | Open pre-trained models | Respective licenses | See §4.2 |
| Cloud dialogue | DeepSeek API | Commercial API | Only the dialogue model runs in the cloud |

> ⚠️ **An important boundary to state clearly**: what Synaptics open-sources on GitHub is the
> **Astra Yocto BSP** (kernel, board support, multimedia, NPU runtime).
> **DisplayLink's DLSDK is not included** — it is a separately supplied closed-source binary,
> currently under NDA. Per the official application note, **DLSDK (officially "DisplayLink Direct")
> is scheduled for public release on 2026-08-01**, which will significantly lower the
> open-source / productization barrier for this product line.

### 2.3 What We Built on Top

| Deliverable | Description |
|---|---|
| **`meta-dlsdk` Yocto layer** | Packages DLSDK into Yocto — udev rules, automatic firmware upgrade, dependency consolidation |
| **4 display applications** | `dl_face` / `dl_player` / `dl_clock` / `dl_edid` (all in-house C programs) |
| **Voice terminal** | `astra_voice` (C) + four-layer routing (Python) + bilingual subtitle daemon |
| **Complete flashable image** | Produced by a single `bitbake astra-media`, using the existing flashing workflow |

### 2.4 Test Environment

| Item | Description |
|---|---|
| Build environment | WSL2 Ubuntu 22.04, Yocto scarthgap |
| Cross-compilation | aarch64 (`gcc-cross` 13.3.0) |
| Board connectivity | Direct SSH over LAN; remote debugging via WireGuard tunnel when off-site |
| Test period | 2026-07-13 – 2026-07-24 (approx. 10 days) |
| Data collection | Frame rates from in-program counters emitted every 60 s; CPU from `/proc/stat` deltas (not a single `top` sample) |

---

## 3 · Multi-Display Capability (Key Section)

### 3.1 Four-Display Concurrent Test Results

**All 4 DL7400 outputs were driven simultaneously.** All four frame counters kept advancing;
none stalled.

| Display | Model | Vendor ID | Resolution | Port | Measured FPS |
|---|---|---|---|---|---|
| 0 | Sculptor portable (HDMI) | YCT 0xAC00 | 2880×1800 @60 | `^0` | **8.7 fps** |
| 1 | Redmi 27 NU | XMI 0xB005 | 3840×2160 @60 | `^1` | **5.8 fps** |
| 2 | S24D390 (Samsung) | SAM 0x0B65 | 1920×1080 @60 | `^2` | **15.0 fps** (capped) |
| 3 | Mi Monitor | XMI 0x27B4 | 3840×2160 @60 | `^3` | **5.7 fps** |

### 3.2 Bandwidth Sharing (3-display vs 4-display)

| Configuration | 4K display FPS | 1080p display FPS |
|---|---|---|
| 3 displays (4K + 1080p + 4K) | **7.2 fps** | 15.0 fps |
| 4 displays (2880×1800 + 4K + 1080p + 4K) | **5.8 fps** | 15.0 fps |
| Change | **↓ ~20%** | unchanged (already at the app's cap) |

**Conclusion**: total USB 3.0 (5 Gbps) throughput stays roughly constant — **adding a display
divides the existing share rather than degrading linearly**. The 1080p display always reaches
the application's 15 fps cap because its pixel count is small.

### 3.3 Video Playback — Bottleneck Analysis

4K VP9 → 1080p, measured over 150 frames:

| Pipeline stage | Time | FPS | Note |
|---|---|---|---|
| Hardware 4K VP9 decode only | 1.35 s | **111 fps** | Decoding is not a constraint |
| ＋ software `videoconvert/videoscale` | 17.55 s | 8.5 fps | ❌ Wastes 94% of the time |
| ＋ hardware `synavideoconvertscale` | 5.63 s | **31.9 fps** | ✅ 3.7× faster — pipeline ceiling |
| ＋ `appsink sync=true` (timestamp-paced) | — | 17.6 fps | |
| ＋ push to DL7400 | — | **7.4 fps** | ★ **The real bottleneck is the DL transfer** |

**Live camera**: C920 MJPEG 720p30 → pushed to a 4K display, measured **7.0 fps**.

### 3.4 ⚠️ A Misleading Benchmark We Must Correct

| Content type | Resolution | FPS |
|---|---|---|
| **Real video** (4K VP9 → 1080p) | 1920×1080 | **7.4 fps** |
| Synthetic test pattern (one moving bar) | 1920×1080 | 60.3 fps ⚠️ **Do not use for planning** |

DisplayLink's DL3+ compression **transfers only changed regions**. A synthetic pattern transfers
almost nothing → inflated FPS. Real video changes every pixel every frame → about 1/8 the rate.
**The earlier 60 fps figure derived from synthetic patterns is withdrawn.**

### 3.5 Performance Positioning

| Use case | Feasibility |
|---|---|
| Digital signage / dashboards / clocks (low-change content) | ✅ **Well suited** — plays to DL3+ compression's strength |
| Interactive UI / subtitles / status display | ✅ Well suited |
| Camera monitoring feed | ⚠️ 7 fps — usable but not smooth |
| Full-screen smooth video / video wall | ❌ **7.4 fps — not viable** |

---

## 4 · Voice Interaction Capability

### 4.1 System Architecture

```
[Vision] C920 camera → NPU person detection (25 ms/frame) → approach → auto greeting

[Voice]  C920 mic → silero VAD segmentation → SenseVoice ASR (CPU)
                                                  ↓
                                        Four-layer routing
                                        ① Local volume commands  → amixer, actually executed
                                        ② Local device queries   → time / temp / memory / display
                                        ③ Live web search        → search API + factual grounding
                                        ④ Cloud dialogue         → DeepSeek
                                                  ↓
                                        matcha TTS (CPU) → amplifier

[Display] Animated face + real-time bilingual subtitles → DL7400 multi-display
          Any display can be switched to the live camera feed by voice
```

### 4.2 On-Device Model Performance (Measured)

| Stage | Model | Measured | Runs on |
|---|---|---|---|
| Person detection | mobilenet224_full1 | **25 ms/frame** | **NPU** |
| Voice activity detection | silero VAD | real-time | CPU |
| Speech recognition | SenseVoice **int8** | **RTF 0.197** (4 threads) = **5× real-time headroom** | CPU |
| Speech synthesis | matcha + vocos | **RTF 0.37** (warm synthesis) | CPU |
| Offline fallback LLM | Qwen2.5-0.5B Q8_0 | 19.6 tok/s | CPU |
| Cloud dialogue | DeepSeek | — | Cloud |

**ASR thread scaling**: 1 thread RTF 0.626 → 2 threads 0.338 → **4 threads 0.197** (near-linear).

**Quantization gain (SenseVoice fp32 → int8)**: **1.45× faster**, **3.3× less memory**
(1287 MB → 393 MB).

**TTS selection iteration**: melo RTF 2.05 (unusable) → matcha RTF 0.37, a **5.5× speedup**.

### 4.3 End-to-End Latency

| Scenario | Measured |
|---|---|
| Local commands (time / volume / display switch) | **Instant** (no cloud round-trip) |
| One cloud dialogue turn | **5 – 12 s** (depends on answer length) |
| Live-data question (e.g. weather) | **~5 s** (2.3 s search ＋ LLM) |
| First TTS sentence | Streamed — **~1 s to first audio** (does not wait for full generation) |

### 4.4 Implemented Features

| Feature | Status | Verified example |
|---|---|---|
| Bilingual (ZH/EN) speech recognition | ✅ | SenseVoice mixed ZH/EN |
| Cloud dialogue | ✅ | "Who are you?" → "I'm the Astra voice assistant" |
| **Live web data** | ✅ | "Weather in Guangzhou today" → "Cloudy to clear, 26–35 °C" — **real data** |
| Local device queries | ✅ | "What time is it?" → actual system clock |
| Voice volume control | ✅ | "Set volume to 20%" → actually applied |
| Voice display-content switching | ✅ | "Open the camera" → target display shows live feed |
| Vision wake | ✅ | Plays a greeting when someone approaches |
| **Real-time bilingual subtitles** | ✅ | Two lines on screen: "You said / Astra", ZH with EN |
| Offline fallback | ✅ | Automatically falls back to the on-device 0.5B model |
| Full recovery after power loss | ✅ | Including one unplanned power-cycle |

### 4.5 Hallucination Suppression (Technical Highlight)

We found that one vendor's "web search" tool in its chat API **does not actually work**:
it returned **zero search results**, yet the model still **fabricated a temperature**
(15–25 °C / 18–28 °C against an actual 28–36 °C — and two models contradicted each other).

**Our approach**: call a standalone search API to obtain real web content, then pass it to the LLM
with a grounding prompt ("answer only from this material; never fabricate any number").
When search fails, hard-real-time questions (weather, stock prices) **say so honestly rather than
falling back** to a model with no live data.

**Result**: zero fabrication on live-data questions.

---

## 5 · Resource Utilization

| Scenario | CPU (sum over 4 cores; 100% = one core saturated) |
|---|---|
| Before optimization (3 displays + voice idle) | 52.5% |
| **After optimization** (same configuration) | **21.7%** |
| Current (3 displays: 2×4K + 1×2880×1800) | dl_face 167% + astra_voice 110% |

**Optimizations applied**: display refresh 15 fps → 5 fps (pixel throughput 311 → 104 MB/s);
throttled the vision detection loop (back-to-back → 0.5 s interval).

> With two 4K displays among three, pixel throughput is about 436 MB/s and CPU rises accordingly —
> **display count and resolution are the dominant cost.**

---

## 6 · Engineering Deliverables

| Deliverable | Contents |
|---|---|
| **Yocto layer `meta-dlsdk`** | One layer covering DLSDK + dependencies + applications + services + fonts |
| **Complete flashable image** | 2.5 GB — works on boot (models and API key still loaded separately) |
| Display applications | `dl_face` (face + subtitles) / `dl_player` (video) / `dl_clock` / `dl_edid` (diagnostics) |
| Voice applications | `astra_voice` (main) + `astra_llm.py` (four-layer routing) + `astra_translate.py` (bilingual subtitles) |
| Documentation | Project summary, flashing guide, backup & recovery manual, DisplayLink issue report (bilingual) |

**Build**: `bitbake astra-media` produces a fully-featured image using the existing flashing workflow.

---

## 7 · Key Technical Findings (For Internal Reuse)

### 7.1 DL7400 Integration

1. **DLSDK is pure userspace libusb** — no kernel module required; `meta-dlsdk` builds it directly
2. **USB 3.0 is mandatory** — the SDK refuses to drive the device at USB 2.0
3. **Never trust `preferred_mode` blindly** — one monitor's EDID advertises 4K@160Hz as preferred;
   the DL7400 cannot feed that and the frame push **blocks forever**. Must clamp to ≤60 Hz
4. **DLSDK is single-process exclusive** — while one process holds the device, a second enumerates zero
5. **The desktop cannot be extended onto these displays** — DLSDK is a "push pixels" API with no
   DRM/KMS node; the application must render its own content. For content-wall use cases this is
   actually an advantage in control

### 7.2 Judge "Is the Display Actually Working" by Frame Count, Not by Eye

| Symptom | Meaning | Fix |
|---|---|---|
| Frame counter **frozen** | Link stalled | Lower refresh rate / deep USB reset |
| Frame counter **rising but screen black** | Link fine — monitor input source is wrong | Switch input source on the monitor's OSD |

**These two have completely different causes and fixes; conflating them wastes a lot of time.**

### 7.3 Voice Side

1. **The NPU only helps vision** — the entire voice pipeline runs on CPU
   (Synaptics' own voice examples do the same)
2. **Quantization gains vary by model and must be measured individually** —
   SenseVoice int8 is 1.45× faster, but VITS int8 was 1.9× *slower*
3. **A pure energy threshold cannot separate speech from ambient noise** —
   measured office noise floor RMS 575–713 versus speech 470–1170: **the ranges overlap**.
   A wake word is the real solution for far-field use

---

## 8 · Known Limitations and Next Steps

| # | Issue | Impact | Plan |
|---|---|---|---|
| 1 | **False triggering from ambient noise** | Requires speaking within ~30 cm in noisy rooms | Integrate KWS wake word (assets already on device) |
| 2 | **Display does not relight after power cycle** | Needs a voice command or service restart | Issue report submitted to DisplayLink |
| 3 | **No acoustic echo cancellation (AEC)** | Currently drops capture frames during playback | To be evaluated |
| 4 | **On-board microphone driver issue** | Using a USB microphone instead | Requires Synaptics FAE support |
| 5 | **TTS licensing** | espeak-ng is GPLv3 and propagates through the whole chain | **Must be resolved before productization** |
| 6 | New image not yet flash-verified on hardware | — | Pending |

### DL7400 Power-Cycle Recovery Issue (Reported to Vendor)

We identified three SDK-level problems and submitted a bilingual report:

1. Hotplug callback registration **always fails**, so display arrival/removal events never arrive
2. EDID / preferred mode / display count are **all cached** — they still report success after a
   monitor is powered off
3. The one interface that does reflect reality (AUX read) **blanks every output on that device**
   when called concurrently with frame streaming

**Conclusion**: there is currently no safe in-band detection method at the SDK level.

---

## 9 · Commercial Positioning

**Good fit**:
- Multi-display digital signage / retail guidance screens / showroom content walls
- Voice interaction terminals (reception, guided tours, assisted-care monitoring)
- Multi-display dashboards and monitoring boards with low-change content

**Poor fit**:
- Video walls or multi-channel video surveillance playback (insufficient frame rate)
- Office scenarios requiring desktop extension (DLSDK provides no DRM/KMS)

**Cost advantage**: a single SL1680 plus one DL7400 drives 4 displays, and the voice AI runs
entirely on-device (only the dialogue model is in the cloud) — no GPU or additional PC required.
