# SL1680 Work Summary — Web Console + TD7800 Touch Kiosk Live

**Date**: 2026-08-05　**Version**: v3.0 (tagged)
**Commit**: `6fa9e0e` @ `feat/pca9685-servo-driver` ([PR #2](https://github.com/hardyhuang818/sl1680-astra-terminal/pull/2), 37 files, +6504 lines)
**Environment change**: the board moved to the office with the BE3600; all work done remotely over a WireGuard jump host (`192.168.8.186`)

---

## 0. One sentence

**The TM10.5-TD7800 touch panel went from being a "display" to being a "console"** — PC/phone
browsers and the touch panel share one Web console that can toggle services, adjust volume,
speak test TTS, drive servos (including speed control), and watch power rails and the live
conversation stream. **All eight power-cycle re-verification checks passed green — fully
automatic recovery.**

---

## 1. Today's main line: from plan to on-screen

| Step | Result |
|---|---|
| ① Study the Robot PDF | Synaptics tactile solution (SN6012T 60-channel force-sensing ASIC + CTS module, SPI/I2C/3.3V). Their dexterous-hand PoC ships with a GUI for visualization — which validated the console direction. The material is under NDA; key points were distilled into §5 of the plan document and the original file is excluded from the repo |
| ② GUI plan + prototype | Compared three routes and settled on a **zero-dependency on-board Web service** (python3 stdlib, ~400 lines); the clickable UI prototype passed review |
| ③ M1 implementation | `astra_webctl.py` (9 whitelisted APIs) + touch-friendly frontend + systemd service, deployed remotely over WireGuard |
| ④ Kiosk route | Official package feed `astra-packages.synaptics.com` is **NXDOMAIN** on the public net (the apt shortcut is dead) → wired up **meta-webkit (scarthgap branch)** → built **cog 0.18.5 + wpewebkit 2.46.7** (3981 tasks all green) → installed as debs by hand (no image reflash) → `astra-kiosk.service` runs full-screen on DSI-1 |
| ⑤ On screen | The TD7800 shows the console; weston's touch calibration / 180° rotation are inherited automatically, touch works out of the box |
| ⑥ Power-cycle re-verification | Six services autostart / API / kiosk auto-load / touch / C920 / servo auto-wake / display / sha256 reconciliation — **all eight green** |
| ⑦ Commit | v3.0 commit + tag + Yocto integration recipe (`recipes-connectivity/astra-webctl/`) |

## 2. What the console can do

- **Service toggles**: voice / vision wake / multi-screen face / timer reminders / clock screen (dl-face↔dl-clock mutual exclusion enforced server-side) + restart display service, panel 29h wake
- **Voice**: volume slider (closed the loop with a 15%/85% listening A/B test), mic gain (clipping warning turns red above 60%), **TTS test speech**, trigger the welcome phrase
- **Servos**: CH0/CH1 angle sliders + **speed slider** (rightmost = full-speed direct) + demo sweep + always-visible red E-stop
- **Vision**: camera snapshot (2 s refresh) + live detection box height (a calibration ruler for threshold tuning)
- **Dashboard**: INA3221 power-rail voltage/current, CPU/memory/disk/uptime, touch IRQ count, device presence, **live conversation stream**
- Deliberately left out: a reboot button (soft reset is unreliable on this board) and arbitrary command execution (everything is whitelisted)

**Access**: touch the TD7800 directly ｜ phone on BE3600 Wi-Fi → `192.168.8.186:8080` ｜
PC from outside: `ssh -N -L 18080:192.168.8.186:8080 root@192.168.5.1` then open `localhost:18080`

## 3. Seven problems fixed today

| # | Symptom | Root cause | Fix |
|---|---|---|---|
| 1 | Servo doesn't move | After power loss the PCA9685 defaults to **SLEEP** — registers accept writes but no PWM comes out | Auto-wake before any output write |
| 2 | Still doesn't move after wake | The sticky **EXTCLK bit** got set accidentally, stopping the oscillator (datasheet: only power-off or SWRST clears it) | Automatic General-Call **SWRST** (send 0x06 to address 0x00) then re-init |
| 3 | Volume dragged to 54% snaps back to 34% | WPE touch drags **never fire onchange** (the value was never submitted) + the anti-overwrite guard wrote `window[id+"Touched"]` but read a `let` variable — **two different bindings** (the guard never worked) | Sliders now use input + 350 ms debounced submit; unified TOUCH object |
| 4 | Camera snapshot shows broken image | Route matching used strict equality, so the `?t=` cache-buster caused 100% 404s; plus non-atomic `cp` could serve a half-written JPEG | Strip the query string before routing; JPEG head/tail validation + cached fallback; frontend swaps the image only after successful preload |
| 5 | C920 fails to enumerate at boot (-71) | Electrical-level handshake failure (a known quirk); remote hub reset does nothing | User re-plugged into another port; **also fixed vision_wake silently falling back to video3** (now exits explicitly and auto-retries — self-heals on re-plug) |
| 6 | "Dependencies satisfied" misjudged twice | **The board has no ldd** — grep over empty output passes everything | `LD_TRACE_LOADED_OBJECTS=1` calls ld.so directly; converged in one round (libwpe → 12 more incl. atk → gstfft) |
| 7 | MODE1 occasionally reads wrong during ramps | The status probe and servo writes race on the **I2C register pointer** | Skip the probe while a ramp is in progress |

## 4. New capability: servo speed

A 180° positional servo has **no hardware speed control** (pulse width only commands position).
Implemented **software constant-rate ramping**:

```bash
python3 pca9685.py move 0 135 30    # CH0 moves to 135° at 30°/s
```

Current angle is read back from the OFF registers (no state to keep). Measured at a commanded
40°/s, register sampling showed the slope 10°→37°→64°→93°→121°→149° — an exact match.
The UI speed slider spans 10–180°/s; the rightmost detent = immediate.

## 5. Lessons learned (recorded in VERSION / notes)

1. **meta-webkit must use the scarthgap branch** — master is wrynose-only and fails parsing outright
2. **Closing the deb dependency set requires the Debian rename mapping** (`cairo`→`libcairo2`); the `PKG:` field in pkgdata is the key
3. When **dpkg's books don't match reality** (library present, package unregistered), `--force-depends` is a legitimate tool
4. **WPE touch**: range sliders must use input + debounce — never rely on onchange
5. `let x` and `window.x` are two different bindings — this JS fundamentals trap masqueraded as "polling overwrites my value"
6. The INA3221 should only be read via the labelled `in1/2/3` (bus voltages); `in4/5/6` are shunt voltages that swing wildly with load
7. All Call 0x70 / General-Call SWRST are the PCA9685's two no-soldering rescue channels

## 6. Versions and leftovers

```
main ──┬── feat/td7800-reset-level-domain   PR #1  (v2.9 voltage-domain diagnosis)
       └── feat/pca9685-servo-driver        PR #2  (servos + v3.0 console/kiosk)  ← tag v3.0
```

| Leftover | Notes |
|---|---|
| kiosk recipe not yet cleanall-verified | The board runs hand-installed debs, already verified; the recipe was written from the live state but never executed. Verify it at the next image build (low risk: worst case is ten minutes of dpkg remediation) |
| Second PCA9685 | Needs A1 bridged → 0x42 (0x40/41 are taken by the on-board INA3221s) |
| M2 to do | Vision-wake threshold write-back; reminder/memory editing in the UI |
| Long-standing | AEC echo cancellation, KWS wake word, espeak-ng GPLv3 licensing, LVDS → twisted pair |

---

*Related: `PC控制台GUI方案_2026-08-05.md` (plan and control-point inventory) · `meta-dlsdk/VERSION` (full v3.0 entry) ·*
*`TD7800触摸根因与视觉唤醒修复_2026-07-28.md` (previous milestone)*
