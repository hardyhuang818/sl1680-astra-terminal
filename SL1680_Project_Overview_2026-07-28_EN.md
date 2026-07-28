# SL1680 Edge-AI Terminal · Project Overview

**Date: 2026-07-28**　Version: v2.7　Device: Synaptics SL1680 (Astra "Dolphin" RDK)
**Positioning: this is the single top-level overview of the project** — three achievement domains, key knowledge, asset inventory, open issues, and a document navigator. All earlier topic documents are indexed from Section 9; no more digging through scattered files.

---

## 1. The Project in One Sentence

An **edge-AI human-machine terminal** built on the Synaptics SL1680 (4×Cortex-A73 + NPU): local voice AI (recognition/synthesis fully on-board) + two display chains (DisplayLink DL7400 USB multi-display + TC358775 direct-drive LVDS touch panel) + visual wake-up — all self-recovering after power loss.

**Test conditions**: the open-source Astra SDK from GitHub (Yocto scarthgap) + one borrowed SL1680 RDK and one DL7400 EVK + self-purchased peripherals (C920 camera, 4 self-owned monitors, TM10.5-TD7800 touch panel, LAMTL adapter board, amplifier/speaker, etc.).

## 2. System Architecture

```
                     ┌───────────────────────── SL1680 (4×A73 + NPU) ─────────────────────────┐
                     │                                                                         │
[C920 camera] ──USB──►│ NPU: mobilenet person detect 25ms/frame ─► approach ─► visual wake     │
[C920 mic]    ──USB──►│ CPU: silero VAD ─► SenseVoice ASR(int8) ─► 4-layer routing            │
                     │      ①local volume ②local device ③web search (Zhipu+grounding)          │
                     │      ④cloud DeepSeek ─► matcha TTS ─► ALSA astraout ─► [HT517+speaker]  │
                     │                                                                         │
                     │ Display A: dl_face ─► GStreamer ─► [DL7400] ──USB3──► up to 4 monitors  │
                     │            screen0 = face+bilingual subtitles, screen1 = live camera    │
                     │ Display B: weston ─► DSI 4-lane ─► [LAMTL/TC358775] ──LVDS──►           │
                     │            [TM10.5-TD7800 1280×720 touch panel] (touch I2C+INT, ~120Hz) │
                     └─────────────────────────────────────────────────────────────────────────┘
   Cloud: DeepSeek (dialogue/translation) + Zhipu standalone search API │ Offline fallback: local qwen2.5-0.5b
```

## 3. Three Achievement Domains

### 3A. Local Voice-AI Terminal (v2.0 → v2.6)

| Capability | Key points | Measured |
|---|---|---|
| Fully local speech chain | SenseVoice ASR (int8) + matcha TTS, no PC required | ASR RTF 0.197 (4 threads); TTS 0.37 |
| 4-layer reply routing | Volume/device commands really execute locally; realtime questions use real search + grounding; chat goes to DeepSeek | "Set volume to 20%" → amixer measured [20%] |
| Visual wake-up | NPU person detection → SIGUSR1 → greeting | 25 ms/frame |
| Bilingual subtitles | astra_translate daemon, two-line CN/EN on screen | ✓ |
| Microphone guard | Waits on card-name + capture-node; survives an 86 s USB flap without spinning | Adversarial test: 0 model reloads |
| Stability | Full recovery after power cycles; daily 4:00 cleanup | Re-verified across reboots ✓ |

### 3B. DL7400 USB Multi-Display

| Conclusion | Data |
|---|---|
| 4 simultaneous monitors feasible | Concurrent frame rates 8.7 / 5.8 / 15.0 / 5.7 fps |
| USB3 total bandwidth constant; more screens = slower each | 3→4 screens: 4K drops 7.2→5.8 fps (−20%) |
| Pipeline bottleneck is DL streaming | 111 → 31.9 (HW scale) → 7.4 fps measured stage by stage |
| 3 SDK defects reported to DisplayLink | Hotplug callback always fails / EDID cached / dpaux blackout trap |
| ⚠️ Monitors don't relight after power loss | Current workaround: voice command "re-detect screens" restarts dl-face |

### 3C. TD7800 LVDS Touch Panel Direct Drive (v2.7, added 2026-07-27/28)

Lit after peeling six root-cause layers; display + touch both working; power-cycle self-recovery 9/9 measured:

| # | Root cause | Fix |
|---|---|---|
| 1 | Base device tree carried Raspberry-Pi panel leftovers | Replace dsi_panel node with TM10.5 timing |
| 2 | TC358775 powers up tri-stated, nobody initializes it | 29 DSI generic-long-write commands baked into DTB |
| 3 | Panel RESX floating (whole TDDI in reset) | Tie high to 3.3V in hardware |
| 4 | U-Boot muxed the SPI data pads to UART2 flow control | Reclaimed via dts pinmux (bonus: SPI debug channel) |
| 5 | Zero bandwidth margin DSI→LVDS → live full-screen noise | Byte_clk 65300 + LVCFG PCLKDIV=4 (+33% margin) |
| 6 | Touch INT GPIO bank ambiguous | Located empirically as porta10 (ATTN latches low → drain over I2C → whichever releases is it) |

Companion outputs: TD7800 SPI debug tool (device-code read / BIST / NVM read), 120 Hz multitouch reporting, 180° display rotation + touch calibration, Shanghai timezone.

## 4. Key Knowledge Distilled (paid for in debugging, reusable across projects)

1. **DSI→LVDS bridges need bandwidth margin**: LVDS pixel clock = DSI clock-lane frequency ÷ PCLKDIV; DSI protocol overhead (headers/EoTp/LP) eats a zero-margin budget → line-buffer underrun = live noise
2. **TDDI reset discipline**: TP_RST/RESX is the master switch of the whole chip — floating kills everything, SoC control kills the display; always tie high in hardware
3. **Level-domain discipline**: feeding 3.3V into a 1.8V-domain pin back-feeds through ESD diodes and lifts the rail (measured 2.38V)
4. **Never trust EDID preferred_mode**: a monitor advertising 160 Hz preferred blocked the DL7400 forever; the fault travels with the monitor and mimics broken hardware
5. **Non-48 kHz sample rates crash the kernel audio driver**: the astraout forced-resample chain is a necessity; always address ALSA by CARD=name
6. **Zhipu chat's web_search is fake**: call the standalone search API + grounding prompt; if search fails, say "cannot find it" rather than fall back
7. **Four classes of Yocto traps**: FetchContent hard-disabled (looks like network failure); un-SOVERSIONed .so lands in the wrong package; `:pn-` overrides only work in conf files; build-green ≠ feature-complete (acceptance must inspect the image at debugfs level)
8. **The board is the truth**: the repo lagged repeatedly; after changing the board, backflow immediately and reconcile sha256
9. **Three laws of remote ops**: complex commands always as script files (PowerShell re-splits args); check busybox gaps first (head -c/timeout/install/base64); guard binary transfers against BOM injection

## 5. Software Assets

| Asset | Location | Notes |
|---|---|---|
| Yocto layer | `meta-dlsdk/` (VERSION v2.7) | astra-voice / dl-face / sherpa-onnx / dlsdk / **linux-syna.bbappend (TD7800 patch)** |
| Full image | `flash_image_20260723163055/` | SYNAIMG 2.5 GB, flash-and-go (models loaded separately) |
| TD7800 boot bundle | `SL1680_td7800_boot/` | three image generations + flash/verify scripts + retrospective README |
| Model backup | `backups/models_2026-07-24/` | 1.15 GB sole copy (⚠️ etc_astra.tar.gz contains plaintext keys — never share) |
| Debug-code backup | `TD7800_bringup_backup_2026-07-28/` | 79 files + SHA256: dts/patch/43 board scripts/27 WSL scripts/evidence frames |
| Rootfs trio on board | /etc on board | 180° rotation / touch calibration / timezone (to be moved into Yocto) |

**Building**: `source poky/oe-init-build-env build-sl1680 && bitbake astra-media`; kernel-only rebuild 75 s (`bitbake linux-syna -C compile` + `-c deploy -f`); boot flashed by dd to both slots + python read-back verify (~4 min end-to-end).

## 6. Hardware Assets and Wiring

| Device | Interfaces | Wiring doc |
|---|---|---|
| SL1680 RDK | J208 (DSI 22P) / J32 (40P header; occupancy table in the Wiring Reference) | Wiring Reference §1/§3 |
| LAMTL adapter | J1 (DSI in) / J3 (LVDS out) / J2, J4 unused | ibid. §1/§2 |
| TM10.5-TD7800 | U4 (LVDS+touch) / U5 (power/SPI/reset) / U3 (backlight LED) | ibid. §2/§3 |
| DL7400 EVK | USB3 upstream + 4× DP/HDMI | plug and play |
| Audio kit | HT517 amp (I2S on J32) + speaker; mic = C920 | Xiaozhi-kit wiring guide |
| External supplies | 12V backlight (via external driver board → LED) / 3.3V panel+resets / 1.8V LAMTL | Wiring Reference §4 (incl. level-domain warnings) |

## 7. Current Running State (measured on board, 2026-07-28)

| Item | State |
|---|---|
| Auto-start services | astra-voice / astra-translate / dl-face / vision-wake / cleanup.timer ✅; astra-mode, astra-xiaozhi, dl-clock disabled |
| Displays | DL7400 multi-screen ✅ + TM10.5 LVDS desktop ✅ (180° rotated, CST clock) |
| Touch | 0x2C claimed by driver, IRQ porta10, evtest reporting, orientation calibrated ✅ |
| boot | `boot_td7800_touch.subimg` (sha 0aa90172…) in both slots; rollback backups in /home on board |
| Power-cycle recovery | 9/9 self-check items pass (display, touch, calibration, timezone, SPI channel) |

## 8. Known Open Issues (merged, project-wide)

| # | Issue | Priority |
|---|---|---|
| 1 | **KWS wake word not integrated** — false triggers burn cloud API; assets complete in `/home/voice/kws/`, only wiring-in missing | ★ Highest |
| 2 | No AEC echo cancellation (currently drops capture frames during playback) | High |
| 3 | DL7400 no self-heal after monitor power loss (3 SDK defects, reported to DisplayLink) | Medium (awaiting vendor) |
| 4 | On-board mic ZTS6672 driver issue (needs Synaptics FAE) | Medium |
| 5 | TTS licensing: espeak-ng GPLv3 propagates through the chain (must solve before productization) | Medium |
| 6 | New image not yet flash-verified on real hardware | Medium |
| 7 | Replace LVDS jumper wires with twisted pairs (works today, but marginal) | Low |
| 8 | Cleanall clean-build verification of the TD7800 patch | Low |
| 9 | Move the rootfs trio (tzdata/rotation/touch calibration) into Yocto | Low |

## 9. Document Navigator (the cure for scatter — remember this section only)

**Top level** (start here):
- This document, *SL1680 Project Overview 2026-07-28* (CN/EN, md+html) — the single top entry
- *SL1680 Project Summary 2026-07-23* (CN/EN) — v2.6 voice-terminal deep dive (most complete build-bug list)

**TD7800 panel topic** (the v2.7 domain):
- *TM10.5_TD7800 Display Bring-up Summary 2026-07-28* (CN/EN, md+html) — six root causes + changes and paths
- *SL1680_TD7800_LAMTL Hardware Wiring Reference 2026-07-28* (CN/EN, md+html) — pin-by-pin baseline
- *TC358775 Configuration & Debug Record 2026-07-28* (md+html) — 29 init commands annotated + raw error logs
- *TD7800 SPI ID-read & BIST Source Code 2026-07-28* (md+html) — complete SPI tool code
- `TD7800_bringup_backup_2026-07-28/README` — 79-file backup inventory

**Reporting & comparisons**:
- *SL1680+DL7400 Achievement Report 2026-07-24* (CN/EN) — the management-facing 4-screen + frame-rate version
- *SL1680 vs ESP32 comparison 2026-07-24* — platform selection
- Robot-finger actuation survey / capacitive tactile survey / iCub fingertip paper digest — robotics groundwork

**Operations**:
- *SL1680 Backup & Recovery Manual 2026-07-24* — how to use the five backup sets
- `SL1680_td7800_boot/README` — flashing and rollback
- `meta-dlsdk/VERSION` — version ledger; `backups/CHANGELOG.md` — day-by-day changes

## 10. Roadmap

1. **Integrate KWS** (kills false triggering and unlocks "pause by voice" in one move)
2. Real-hardware flash verification of the new image + move the rootfs trio into Yocto → hand colleagues a "one-flash, full-function" deliverable
3. Robotics direction: SL1680 torso compute + TM10.5 face + DL7400 teleoperation console + finger actuators (surveys ready) — aligned with Synaptics' official "high-speed interfaces × robotics" narrative
