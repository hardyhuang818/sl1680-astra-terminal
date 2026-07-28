# SL1680 + LAMTL (MIPI→LVDS) + TM10.5-TD7800 Hardware Wiring Reference

Date: 2026-07-28 | Status: **Wired per this table and verified working (display + touch); use as the jumper-wiring reference baseline**
Companion docs: *TM10.5_TD7800 Display Bring-up Summary 2026-07-28*, `TD7800_bringup_backup_2026-07-28/`

---

## 0. Devices and Connection Overview

```
                        ┌──────────────────────────────┐
  SL1680 dolphin RDK    │  LAMTL adapter (TC358775)     │        TM10.5-TD7800 panel
┌─────────────────┐     │  J1: 30P FPC  DSI input       │      ┌──────────────────────┐
│ J208: 22P FPC   │─A──▶│  J2: 6P      backlight (unused)│─B──▶│ U4: 40+2P LVDS+touch │
│   (MIPI-DSI)    │     │  J3: 2×15P   LVDS output      │      │ U5: 40+2P pwr/SPI/rst │
│ J32: 40P header │──┬──┘  J4: 3P      VCC_LVDS jumper   │      │ U3: 10+2P backlight   │
└─────────────────┘  │                 (unused)                └──────────────────────┘
                     ├─C─▶ Touch I2C+INT (U4 pins 34/35/36/38)
                     └─D─▶ SPI debug (U5 pins 1/2/3/4)
  External supplies: 12V (backlight, direct to U3) · 3.3V (panel VDD/RESX/TP_RST) · 1.8V (LAMTL)
  — all sharing common ground with the board
```

- Segment A = DSI (4 lanes, 522.4Mbps/lane); Segment B = single-link LVDS (5 pairs, 457Mbps/pair)
- Physical form: U4/U5 broken out via **FPC-to-DIP adapter boards**, DuPont jumpers (works; twisted pairs recommended for segment B in production)

---

## 1. Segment A: SL1680 J208 → LAMTL J1 (MIPI-DSI)

### J208 full pinout (22P 0.5mm FPC, Molex 5255 family)

| Pin | Signal | Goes to |
|---|---|---|
| 1 | PWR_3V3_CTL (switched 3.3V rail) | → J1.6/7 |
| 2 / 3 | TW0_SDA / TW0_SCL (i2c-0) | unused here (touch uses J32.3/5) |
| 4,7,10,13,16,19,22 | GND | common ground |
| 5 | GPIO_DSI (IO expander GPIO0_7) | unused |
| 6 | PWR_ON_DSI (expander GPIO0_1, display enable) | → J1.13 |
| 8 / 9 | MIPI TD3p / TD3n | → J1.17 / J1.16 |
| 11 / 12 | TD2p / TD2n | → J1.20 / J1.19 |
| 14 / 15 | TCKp / TCKn (DSI clock) | → J1.23 / J1.22 |
| 17 / 18 | TD1p / TD1n | → J1.26 / J1.25 |
| 20 / 21 | TD0p / TD0n | → J1.29 / J1.28 |

### LAMTL J1 full pinout (30P 0.5mm FPC) and actual hookup

| J1 pin | Signal | Actual hookup |
|---|---|---|
| 1–3 | VCC12V_LCM | unused (backlight does not go through LAMTL) |
| 4–5 | VCC5V_LCM | unused |
| 6–7 | VCC3V3_LCM | ← J208.1 (PWR_3V3_CTL) |
| 8 | VCC1V8_LCM | ← **external 1.8V** (⚠️ see power warnings) |
| 9 / 10 | I2C_SDA/SCL_LCM (1.8V domain) | **not connected** — bridge is configured over the DSI link |
| 11 | LCM_BL_ADJ | unused |
| 12 | LCM_BL_EN | unused |
| 13 | LCM_PWR_EN | ← J208.6 (PWR_ON_DSI). **1.8V level domain** |
| 14 | LCM_RST | ← **tied high to 1.8V**. ⚠️ Never 3.3V (back-feeds via RESX ESD diode; rail measured lifted to 2.38V) |
| 15,18,21,24,27,30 | GND | common ground |
| 16 / 17 | MIPI_TX_D3N / D3P | ← J208.9 / 8 |
| 19 / 20 | D2N / D2P | ← J208.12 / 11 |
| 22 / 23 | CLKN / CLKP | ← J208.15 / 14 |
| 25 / 26 | D1N / D1P | ← J208.18 / 17 |
| 28 / 29 | D0N / D0P | ← J208.21 / 20 |

> Mnemonic: on J208 the pairs run D0, D1, CLK, D2, D3 from high pin numbers to low; J1 lays them out in the reverse direction — connect straight through, p↔P and n↔N, no crossing.

---

## 2. Segment B: LAMTL J3 → Panel U4 (single-link LVDS)

### LAMTL J3 full pinout (PH2.0 2×15 header)

| J3 pin | Signal (silkscreen) | Actual hookup |
|---|---|---|
| 1–3 | VCC_LVDS (3.3/5V via J4 jumper) | **unused** (U4 has no power pins; panel power enters via U5, so the J4 jumper is irrelevant) |
| 4–6, 13–14, 25–26 | GND | common ground (at least one alongside every pair) |
| 7 / 8 | OD0N / OD0P (A0−/A0+) | → U4.18 / 19 |
| 9 / 10 | OD1N / OD1P | → U4.21 / 22 |
| 11 / 12 | OD2N / OD2P | → U4.24 / 25 |
| 15 / 16 | ODCKN / ODCKP (clock pair) | → U4.27 / 28 |
| 17 / 18 | OD3N / OD3P | → U4.30 / 31 |
| 19–24, 27–30 | ED0~ED3 / EDCK (second link, "B" group) | **all unconnected** (single link uses only the first link = OD group; TC358775 datasheet Fig 5-10) |

### Panel U4 full pinout (FH75-40S-0.5SH, 40+2P)

| U4 pin | Signal | Actual hookup |
|---|---|---|
| 1,4,7,10,13,16,17,20,23,26,29,32,33,37,41,42 | GND | common ground |
| 2/3, 5/6, 8/9, 11/12, 14/15 | LVD0B~LVD3B / LVDCLKB (port B) | **all unconnected** (panel is single-port by design; marked × on its schematic) |
| 18 / 19 | LVD0A− / LVD0A+ | ← J3.7 / 8 |
| 21 / 22 | LVD1A− / LVD1A+ | ← J3.9 / 10 |
| 24 / 25 | LVD2A− / LVD2A+ | ← J3.11 / 12 |
| 27 / 28 | LVDCLKA− / LVDCLKA+ | ← J3.15 / 16 |
| 30 / 31 | LVD3A− / LVD3A+ | ← J3.17 / 18 |
| 34 | /INT TP (touch interrupt) | → **J32.12** (segment C) |
| 35 | /RST TP (touch reset) | → **tied high to 3.3V** (TDDI: must not be SoC-controlled) |
| 36 | TP_SCL | → **J32.5** (segment C) |
| 38 | TP_SDA | → **J32.3** (segment C) |
| 39 | NC | open |
| 40 | FSEL (INTL polarity-inversion period, L=1 frame / H=2 frames) | floating (default; no anomaly observed) |

---

## 3. Segments C/D and Panel Power: U5 / U3 / J32

### Panel U5 (FH75-40S-0.5SH: power / SPI / master reset; verify individual pin numbers against the panel schematic screenshot)

| U5 pin | Signal | Actual hookup |
|---|---|---|
| 1 | SCK (display SPI clock) | ← J32.23 (SPI2_CLK) |
| 2 | SDA (SPI write data / MOSI) | ← J32.19 (SPI2_SDO, board transmits) |
| 3 | SDO (SPI read data / MISO) | → J32.21 (SPI2_SDI, board receives) |
| 4 | SS (chip select CSX) | ← J32.24 (SPI2_SS0n) |
| 7 / 8 | ATREN / ERR (FAIL_DET output) | unconnected (ERR usable as an LVDS-fault observation point) |
| **9** | **RST TFT (RESX, master reset of the whole TD7800)** | → **tied high to 3.3V**. ⚠️ **Bug #1: floating = touch + display + SPI all dead at once** |
| 10–13 | GSPD / GSPU / MUTE / HVR | unconnected |
| 15–18 | VCC_1~4 (panel logic supply) | ← **external 3.3V** |
| 20–23, 25 | GND_1~5 | common ground |
| 24 | NTC | unconnected (backlight thermal sensing; usable in production) |
| 27 / 28 | A_1 / A_2 (backlight LED anodes) | backlight external supply + (same net as U3) |
| 30 / 31 / 32 | C1 / C2 / C3 (backlight LED cathode channels) | backlight external supply − / constant-current channels |

### Panel U3 (FH52-10S-0.5SH, dedicated backlight LED connector)

| U3 pin | Signal | Notes |
|---|---|---|
| 1–3 | A1/A2/A3 (LED anodes, paralleled) | backlight +, **fed directly by the external supply in this project** (LAMTL J2 path unused) |
| 5 / 6 | NTC+ / NTC− (GND) | thermistor, unused |
| 8–10 | C1/C2/C3 (LED cathode channels) | backlight −. ⚠️ Constant-current drive recommended; mind current limiting if driving with a fixed voltage |
| 4, 7 | NC | open |
| 11/12 | GND (shell) | common ground |

### SL1680 J32 header occupancy master table (40P; ⚠️ NOT Raspberry Pi pin conventions — follow the carrier schematic)

| J32 pin | Signal | Current occupant |
|---|---|---|
| 1 | 3.3V | (was on-board mic VDD, mic abandoned) usable as TP_RST / RESX pull-up source |
| 2 | 5V | HT517 amplifier Vin (voice chain) |
| 3 | TW0_SDA | **Touch SDA** (← U4.38) |
| 4 | 5V | free |
| 5 | TW0_SCL | **Touch SCL** (← U4.36) |
| 6 | GND | amplifier GND |
| 7 | PWM[1] | free (backlight PWM candidate) |
| 8 / 10 | UART0 Tx/Rx | debug console |
| 9 | GND | **Touch GND** |
| 11 / 13 / 15 | I2S2 BCLK/LRCK/DI | (was on-board mic, abandoned) |
| 12 | GPIO10 (SoC porta line 10) | **Touch INT** (← U4.34) |
| 14, 20, 25, 30, 34, 39 | GND | grounds available |
| 16 | ADCI[0]/PWM[2] | free |
| 17 | 3.3V | free (second 3.3V tap) |
| 18 | ADCI[1]/GPIO2 | free |
| 19 | SPI2_SDO | **Panel SPI MOSI** (→ U5.2) |
| 21 | SPI2_SDI | **Panel SPI MISO** (← U5.3) |
| 22 | GPIO37 | free |
| 23 | SPI2_CLK | **Panel SPI SCK** (→ U5.1) |
| 24 | SPI2_SS0n | **Panel SPI CS** (→ U5.4) |
| 26 / 36 | SPI2_SS1n / SS3n | free |
| 27–29 | PDM | free |
| 31 / 32 / 33 | GPIO39 / GPIO38 / GPIO36 | free |
| 35 | I2S1_LRCK | amplifier DI1 (LRC) |
| 38 | I2S1_BCLK | amplifier DI0 (BCLK) |
| 40 | I2S1_DO | amplifier DI2 (DIN) |

---

## 4. Power Summary (all supplies share common ground)

| Supply | Source | Destination | Notes |
|---|---|---|---|
| 12V | external supply | backlight LEDs (U3/U5 A/C nets) | constant current recommended; direct drive tested working |
| 3.3V | external supply | panel VCC_1~4 (U5.15–18), **U5.9 RESX pull-up**, U4.35 TP_RST pull-up | panel logic power does not enter via U4/J3 |
| 1.8V | external supply | LAMTL J1.8 (VCC1V8_LCM) | TC358775 LVDS PHY / VDDIO domain |
| 1.8V logic levels | same | high levels for J1.13 PWR_EN and J1.14 RST | ⚠️ 3.3V back-feeds through the ESD diode and lifts the rail (measured 2.38V) |
| 3.3V (from board) | J208.1 PWR_3V3_CTL | LAMTL J1.6/7 | switches with the display power sequence |
| Enable (from board) | J208.6 PWR_ON_DSI | LAMTL J1.13 | expander GPIO0_1, asserted automatically at boot |
| **Common ground** | all external supply negatives + board GND + panel GND | — | verify any two grounds ≈ 0Ω with a meter |

## 5. Wiring Warnings (ordered by cost of the mistake)

1. **U5.9 RESX must be tied high to 3.3V** — floating = whole TD7800 in reset; touch/display/SPI all dead simultaneously (the single biggest trap of this project)
2. **LAMTL RST/PWR_EN must use 1.8V levels** — 3.3V back-feeds through the RESX ESD diode path and lifts the 1.8V rail to 2.38V (measured), overdriving the LVDS PHY
3. **Never give TDDI reset to the SoC** — both U4.35 (TP_RST) and U5.9 (RESX) tied high in hardware; the software touch node deliberately has no reset-gpio
4. **Single-link LVDS uses the OD group (first link)**; ED group and panel port B stay unconnected; never swap P/N within a pair
5. Watch FPC ribbon **same-side vs opposite-side contact orientation**; identify pin 1 before latching
6. Twist each differential pair, keep ≤30 cm, run a ground alongside every pair (loose DuPont wires tested working but marginal)
7. The J4 jumper (VCC_LVDS 3.3/5V) is unused in this design — panel power does not come from J3

---

*Measurement basis: bring-up campaign 2026-07-27/28. Six-layer root-cause retrospective and software configuration: see the Display Bring-up Summary. Verify individual U5 pin numbers against the TM10.5 panel schematic screenshot where precision matters.*
