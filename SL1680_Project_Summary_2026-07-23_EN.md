# SL1680 Voice Terminal · Project Summary

**Date: 2026-07-24**　　Version: v2.6　　Device: SL1680 (Synaptics Astra "Dolphin" RDK)

> This is the **project-level summary** — what the project is, what it can do today, how to build it, and what remains unsolved.
> Day-by-day debugging detail lives in `SL1680调试总结_2026-07-23_完整版.md`.

### Confidence Labels

| Label | Meaning |
|---|---|
| ✅ **Verified** | Directly observed, or re-tested after the fix and confirmed effective |
| ⚠️ **High-probability inference** | The phenomenon is real, but the causal chain is inferred |
| ❓ **To be confirmed** | Needs vendor input / more data before concluding |

---

## 1 · What the Project Is

A **local voice AI terminal** built on the Synaptics SL1680 (4×Cortex-A73 + NPU), with DisplayLink DL7400 multi-display expansion.

**Current form: no PC required.** Speech recognition and synthesis run entirely on the board; only the conversational "brain" goes to cloud DeepSeek.

### Hardware

| Part | Model | Connection |
|---|---|---|
| Main board | SL1680 Dolphin RDK | — |
| Microphone | Logitech C920 (USB audio interface) | USB `1-1.3` |
| Camera | The same C920 (USB video interface) | Same port; both interfaces usable simultaneously |
| Amplifier/speaker | HT517 | I2S, `dolphinasoc` |
| Multi-display | DisplayLink DL7400 (firmware 12.3.26) | USB3 `1-1.1.1`, SuperSpeed |
| Monitors | 3 total: 2× 4K@60 + 1× 2880×1800@60 | DL7400 outputs |

> ⚠️ The on-board microphone ZTS6672 has a driver-level issue (i2s-mic1 clock never enabled); **the C920 substitutes for it** — needs Synaptics FAE support.

---

## 2 · System Architecture

```
[Vision] C920 camera ──► NPU (mobilenet person detection, 25ms/frame)
                           └─► person approaches ──► SIGUSR1 ──► astra_voice plays greeting

[Voice]  C920 mic ──► silero VAD segmentation ──► SenseVoice ASR (CPU, int8)
                                              │
                                              ▼
                                    astra_llm.py 4-layer routing
                                    ① local volume commands   amixer actually executes
                                    ② local device commands   time/temperature/memory/screen switch
                                    ③ web search              Zhipu web_search + grounding
                                    ④ cloud conversation      DeepSeek
                                              │
                                              ▼
                                    matcha TTS (CPU) ──► ALSA astraout ──► HT517

[Display] astra_voice ──► /tmp/astra_status.txt (Chinese)
          astra_translate ──► /tmp/astra_status_en.txt (English)
                              │
                              ▼
                        dl_face ──► GStreamer ──► DL7400 ──► 3 monitors
                        Screen 0 = expression face + bilingual CN/EN subtitles
                        Screen 1 = voice-switchable live C920 camera view
```

### Models per Stage

| Stage | Model | Runs on |
|---|---|---|
| Person detection | `mobilenet224_full1` | **NPU** |
| VAD | `silero_vad.onnx` | CPU |
| Speech recognition | **SenseVoice int8** | CPU |
| **Main dialogue model** | **`deepseek-chat`** | Cloud |
| Web search | Zhipu standalone Web Search API (`search_std`, ~¥0.01/query) | Cloud |
| Offline fallback | `qwen2.5-0.5b-instruct-q8_0.gguf` | CPU |
| CN↔EN translation | Same `deepseek-chat` | Cloud |
| Speech synthesis | **matcha** + vocos vocoder | CPU |

> ✅ The NPU only helps vision. The entire voice chain runs on CPU — Synaptics' own speech samples all run on CPU too.

---

## 3 · systemd Services

| Service | Role | Auto-start |
|---|---|---|
| `astra-voice` | Voice assistant main process (VAD+ASR+4-layer reply+TTS, one resident process) | ✅ |
| `astra-translate` | CN/EN subtitle translation daemon | ✅ |
| `dl-face` | DL7400 conversation UI | ✅ |
| `vision-wake` | Visual wake-up | ✅ |
| `astra-cleanup.timer` | Purge voice segments daily at 4:00 | ✅ |
| `astra-mode` | Dual-mode watchdog | ❌ **Disabled** |
| `astra-xiaozhi` | Cloud xiaozhi client | ❌ Disabled |

> **Why `astra-mode` is disabled**: it probes the PC's port 8000 every 8 seconds and, **on success, `stop astra-voice` and switches to cloud mode**.
> Now that the board is back on the home network — same subnet as the PC — that risk is elevated. Do not re-enable.

---

## 4 · Feature List and Verification Status

All re-verified after a reboot on 2026-07-23:

| Feature | Status | Measured |
|---|---|---|
| Three monitors light up at boot | ✅ | 2×3840×2160@60 + 1×2880×1800@60, `NRestarts=0` |
| Voice dialogue (cloud DeepSeek) | ✅ | "Who are you" → "I am the Astra voice assistant" |
| Live web data | ✅ | "Guangzhou weather today" → "cloudy to sunny, 26–35 ℃", real data |
| Local device commands | ✅ | "What time is it" → "14:29" (real system clock) |
| Voice volume control | ✅ | "Set volume to 20%" → amixer measured `[20%]` |
| Voice-switch to camera | ✅ | "Open the camera" → screen 1 switches to camera + vision-wake auto-stops |
| Voice-switch back to face | ✅ | "Close monitoring" → reset + vision-wake auto-resumes |
| Visual wake-up | ✅ | Greeting plays when a person approaches |
| Bilingual subtitles | ✅ | "You said / Astra" two-line CN/EN on screen |
| Full recovery after power cycle | ✅ | Verified via software reboot; one unplanned reboot also fully recovered |
| No idle-spin when mic drops | ✅ | See next section |

### New in This Version: Microphone Wait Guard

**Problem** (measured 2026-07-23): the C920's `1-1.3` USB bus flaps; a real outage of **86 seconds** was measured.
During it, every `astra_voice` start failed with `cannot open plughw:CARD=C920,DEV=0 (capture): No such device`,
systemd re-launched every 3 seconds, and **each attempt wasted 14–17 s loading models before dying** — 7 crashes in a row.

**Fix**: `ExecStartPre=/usr/bin/astra_wait_mic.sh C920 120` placed first.

Two design points:
1. **Wait by card NAME, not card number** — `/proc/asound/C920` is created by name; the card index changes across boots (C920 measured as card0 sometimes, card2 other times)
2. **Wait for the capture node, not just the card directory** — the card directory appears first; `/dev/snd/pcmC<N>D0c` arrives after udev catches up, and opening within that window fails with `No such file or directory`

**✅ Adversarial verification** (whole-device unbind/bind to simulate a real unplug):

| | Old behavior | New behavior |
|---|---|---|
| While mic absent | 3 crashes + full model load each time | `activating`, **0 model loads, 0 errors, NRestarts 0** |
| Mic re-attached | — | `[wait-mic] C920 ready at second 17` → one model load → listening, **NRestarts 0 throughout** |

---

## 5 · Key Technical Decisions (all learned the hard way)

### Audio: `astraout` is a necessity, not an optimization ✅

The Synaptics driver's `berlin_outdai_hw_params` null-pointer-crashes at **non-48000 sample rates**
(e.g. matcha's 22050), leaving the playback subdevice stuck busy with a dead PID as owner —
**unreleasable from userspace; only a reboot clears it**.

Fix: `/etc/asound.conf` defines `pcm.astraout` = `plug → softvol → plug (force 48000/2ch/S16_LE) → hw`,
so the hardware never sees 22050. **All ALSA addressing must use `CARD=<name>`** — index form `hw:0` breaks when card numbers reshuffle.

### Display: never trust `preferred_mode` blindly ✅

A Xiaomi monitor's EDID advertises 3840×2160**@160Hz** as preferred; the DL7400 cannot drive it and
`dlsdk_display_show` **blocks forever** (deterministically at frame 7). Clamping to 60Hz fixes it instantly.

> This failure looks exactly like "broken monitor / broken cable" because **EDID is a property of the monitor and travels with it**. "Changing the cable didn't help" — same root cause.

### Web data: Zhipu chat's `web_search` tool does not work ✅

Measured `prompt_tokens` of only 21 and 0 `search_result` entries, yet the model **still fabricated a temperature**
(15–25 ℃ / 18–28 ℃ invented; reality 28–36 ℃; the two models even contradicted each other).

The correct approach: call the **standalone search API**, feed real page content with a `GROUND_PROMPT`
("answer only from these sources; never invent numbers") into DeepSeek. When search returns nothing,
**hard-realtime questions (weather/stocks) answer "cannot find it" — no fallback**.

### False triggers: pure energy thresholds cannot work ✅

Measured office noise floor **RMS 575–713** vs. user speech **RMS 470–1170** — **the ranges overlap**.
Raising `--min-rms` to 1150 forces near-field use (within 30 cm).
**The real fix for far-field + noisy environments is KWS wake-word — not yet integrated.**

---

## 6 · Known Unsolved

| # | Issue | Status |
|---|---|---|
| 1 | **Severe false triggering** — office chatter treated as commands, each hitting the cloud API | Needs KWS. `/home/voice/kws/` assets complete on board but not wired in |
| 2 | **DL7400 monitors don't relight after power loss** | Three SDK defects; no safe online detection method. Report filed with DisplayLink |
| 3 | **No AEC echo cancellation** | Currently drops capture frames during playback |
| 4 | **On-board mic ZTS6672 driver issue** | Needs Synaptics FAE |
| 5 | **TTS licensing** | espeak-ng GPLv3 propagates through the whole chain; must be solved before productization |
| 6 | ~~`astra_voice` binary not reproducible~~ | ✅ **Solved in v2.5** — recipe now builds fully, see section 7 |
| 7 | **~2GB of models not inside the image** | Load `/home/voice/` separately after flashing; see `README_models.md` |
| 8 | **Image not yet flash-verified on real hardware** | Board SSH unreachable since the evening of 2026-07-23 |

### The Three SDK Defects Behind DL7400's No-Self-Heal

1. `dlsdk_register_hotplug_callback()` **always returns `DLSDK_UNSUCCESSFUL(2)`** — events never delivered
   - ✅ Platform causes ruled out by measurement (`LIBUSB_CAP_HAS_HOTPLUG=1`)
   - ⚠️ But it is **not** proven the fault is inside libdlsdk — a precondition may be unmet, or the configuration may simply be unsupported
2. EDID / preferred_mode / display count are **all cached** — still returns SUCCESS after the monitor loses power
3. **★ Fatal**: calling `dpaux_read` on a disconnected sink while frames are being pushed concurrently **blacks out every output on that device**

> The dangerous build is archived as `dl_face.c.DANGEROUS_dpaux_DO_NOT_BUILD` — **never compile it into production**.
> The current workaround = say "re-detect screens" by voice to restart dl-face and re-enumerate.

---

## 7 · Repository and Build

### Layout

```
meta-dlsdk/
  VERSION                                  ← version log, append per sync
  recipes-ai/
    astra-voice/astra-voice_1.0.bb         ← voice assistant (new 2026-07-23)
              /files/  astra_voice.c, astra_llm.py, astra_translate.py,
                       astra_wait_mic.sh, astra_setvol.sh, vision_wake.sh,
                       asound.conf, llm.conf.sample, silent.wav, *.service
    sherpa-onnx/sherpa-onnx_1.13.4.bb
  recipes-graphics/
    dl-face/dl-face_1.0.bb                 ← display UI (new 2026-07-23)
    dl-clock/ dl-edid/ dl-player/ dlsdk/
tools/                                     ← remote-ops scripts
backups/                                   ← backup bundles + CHANGELOG + deploy manifest
```

### Building

```bash
cd /home/astra/sdk && source poky/oe-init-build-env build-sl1680
bitbake astra-media          # full image (with the voice terminal)
```

Individual packages: `bitbake astra-voice` / `bitbake dl-face` / `bitbake sherpa-onnx`.

**How the voice terminal enters the image**: `packagegroup-astra-terminal` defines "what this machine is for",
attached to the official Synaptics image by `recipes-core/images/astra-media.bbappend` —
the original build command, flashing flow, image name and artifact layout all stay unchanged.
To opt out: set `ASTRA_TERMINAL_PACKAGES = ""` in `local.conf`.

The output SYNAIMG flash bundle lands in `tmp/deploy/images/sl1680/SYNAIMG/`, ~2.5 GB.

**⚠️ Models are not in any recipe** (~2GB). After flashing, load them into `/home/voice/` separately —
see `files/README_models.md` and `MODEL_MANIFEST.txt`.

### Real Bugs Caught During the Build Work

**Compile layer**

1. **Yocto hard-disables CMake FetchContent** — `cmake.bbclass` passes
   `-DFETCHCONTENT_FULLY_DISCONNECTED=ON`; sherpa's 8 third-party packages cannot download and
   configure fails outright. **The symptom mimics "network down", yet the logs contain no curl/HTTP/timeout entries at all.**
   Fix: pre-fetch 14 packages (4 levels of nesting) via `SRC_URI` → copy into `${S}` to hit `possible_file_locations`
   → then turn that switch off. ⚠️ `openfst`/`eigen` are each requested in two different versions by different subprojects — stock both
2. **`-Werror=format-security`** — espeak-ng resets C flags and drops `-Wformat`;
   the remaining `-Wformat-security` becomes fatal under `-Werror`
3. **Font package name** — it is `ttf-wqy-zenhei`, not `wqy-zenhei`; the wrong name gives `Nothing RPROVIDES` immediately

**Packaging layer** (all of the "build green, explodes on the board" kind)

4. **`.so` without SOVERSION lands in the `-dev` package** — sherpa's CMake never sets SOVERSION,
   and Yocto treats unversioned `.so` as development symlinks. The runtime image simply lacked the library.
   Fixed with `SOLIBS=".so"` / `FILES_SOLIBSDEV=""`, **verified end-to-end** (all 4 `.so` present in the deb)
5. **Prebuilt `libonnxruntime.so` not registered as a symbol-version provider** — declared explicitly via `RPROVIDES`
6. **Third-party files installed to wrong locations** — `sherpa-onnx.pc` under `${prefix}` root, `cargs.h` into `${libdir}`

**Image layer** (caught during v2.6 acceptance; invisible if you only check "build succeeded")

7. **`/etc/asound.conf` collides with `alsa-state`** → `do_rootfs` fails outright.
   Deleted alsa-state's **32-byte placeholder comment** copy
8. **`dl-clock` and `dl-face` both auto-start** → DLSDK is **single-process exclusive**; the two fight over the DL7400,
   presenting as "screens black but services active". dl-clock set to `SYSTEMD_AUTO_ENABLE = "disable"`
9. **`vision-wake` missing from auto-start** → freshly flashed boards don't greet approaching people.
   ⚠️ This was my own misjudgment: I assumed it monopolized the C920, but video/audio are two independent USB interfaces that coexist.
   **Trust the board's measured state; never exclude by assumption**
10. **`synap_cli_od` dependency undeclared** → happened to be present in `astra-media`; silently breaks on any other image

> **`SYSTEMD_AUTO_ENABLE:pn-<recipe>` in another recipe's bbappend has no effect** —
> `:pn-` overrides only work in conf files (local.conf/layer.conf). It must go into the recipe itself.

### Repository vs. Board

> **The board is the truth; the repo has repeatedly lagged behind.** Past incidents: `astra-voice.service` stuck on old hardware config,
> `astra_llm.py` missing all four routing layers, 5 files that never existed in the repo at all,
> and — most dangerous — a board-side rollback of code that blacks out two screens **without the repo source being reverted**.

After changing the board, immediately run `tools/export_live.sh` to export and backflow, then verify against the sha256
table in `backups/2026-07-23/DEPLOY_MANIFEST.txt`. **Judging whether a rollback file is safe requires diffing content, not filenames.**

---

## 8 · Remote Operations

The board lives on the home network at `192.168.5.126` (root/1234), same subnet as the PC.

| Script | Purpose |
|---|---|
| `tools/brun.ps1` / `bsh.ps1` / `bput.ps1` | **Direct** run command / run script / upload file |
| `tools/wgrun.ps1` / `wgsh.ps1` / `wgput.ps1` / `wgget.ps1` | Via WireGuard jump host when the board is away |
| `tools/wgjump.ps1` | Log into the jump host only — distinguishes "tunnel down" from "board down" |
| `tools/export_live.sh` | Export the board's actually-running files + sha256 manifest |

### Six Recurring Traps

1. **Uploads get a 3-byte UTF-8 BOM injected** — harmless for text, **fatal for binaries** (`Exec format error`). Tell-tale: on-board size = local +3
2. **Never write Chinese comments in `.cmd` files** — cmd.exe uses the ANSI codepage; the text garbles and gets executed as commands
3. **`powershell -File` re-splits arguments on spaces** — outer quotes don't survive; `-w` / `$(...)` get grabbed by PowerShell. **Ship remote commands as script files**
4. **busybox gaps** — no `install`, `timeout`, `base64`, `ldd`; `head` rejects `-c`/`-12`; `wget -T` can't bound connect hangs (use `curl -m`)
5. **askpass substring matching** — `findstr /C:"192.168.5.1"` also matches `192.168.5.126`, feeding the jump-host password to the board; the only symptom is a bare `Permission denied`
6. **Don't use `pgrep -f` to find PIDs on the board** — it matches the wrapping sh itself

---

## 9 · Version History

| Version | Date | Content |
|---|---|---|
| **v2.6** | 2026-07-24 | **First "flash-and-go" complete image**; acceptance caught 4 "build-green but feature-incomplete" issues |
| **v2.5** | 2026-07-23 | **sherpa-onnx builds in Yocto for the first time**; root cause was Yocto hard-disabling CMake FetchContent |
| **v2.4** | 2026-07-23 | Microphone wait guard (`astra_wait_mic.sh`), eliminating idle-spin reloads during USB flaps |
| **v2.3** | 2026-07-23 | Codex review remediation: removed dangerous AUX code, full board-config backflow, added two never-existed recipes, fixed sherpa `.so` packaging |
| **v2.2** | 2026-07-23 | Voice "re-detect screens"; three DLSDK diagnostics; DisplayLink issue report |
| **v2.1** | 2026-07-23 | Dual-screen role split + voice camera switch; CPU optimizations; local device tools |
| **v2.0** | 2026-07-23 | Bilingual subtitles; Zhipu web-search grounding |

Full changes in `backups/CHANGELOG.md`; layer versions in `meta-dlsdk/VERSION`.

---

## 10 · Recommended Next Steps

1. **Fix false triggering (top priority)** — integrate the KWS wake word. `/home/voice/kws/` already holds the
   encoder/decoder/joiner int8 models, tokens, and keyword file; `sherpa-onnx-keyword-spotter-alsa` is present too — **only the wiring-in is missing**.
   This also unlocks "pause conversation by voice": today it's impossible because the reply chain's final rule layer always speaks,
   so true silence means stopping capture — and resuming by voice then requires KWS
2. **~~Close the build-verification loop~~** — ✅ **Done** (v2.5/v2.6). All three recipes green,
   full image produced. **But it has never been flash-verified on real hardware — that is now the most important gap to close**
3. **Productization** — smart care / security terminal (demo works; missing multi-camera CSI×2 + recording + alert push)
