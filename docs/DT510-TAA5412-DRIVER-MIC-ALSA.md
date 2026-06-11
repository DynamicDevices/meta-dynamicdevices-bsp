# DT510 — TAA5412‑Q1 “Driver Mic” ALSA capture

**Scope:** **`imx8mm-jaguar-dt510`**, **`sound-taa5412`** (`simple-audio-card,name = "taa5412-codec"`) → ALSA short id **`taa5412codec`**. Confirm with **`grep taa5412 /proc/asound/cards`**.

**Hardware:** TI **TAA5412‑Q1** on **`&i2c2` `0x51`**, digital audio on **`&sai5`**. **`&micfil` disabled** so **SAI5_RXC** is not grabbed by EVK PDM.

---

## Driver stack — Path A vs Path B (pick one per image)

Mutually exclusive **`MACHINE_FEATURES`** (see **`conf/machine/include/taa5412.inc`**, factory override in **`meta-subscriber-overrides/conf/layer.conf`**):

| | **Path A — `taa5412` (BSP default)** | **Path B — `taa5412-tac5x1x-ti` (factory today)** |
|---|--------------------------------------|-----------------------------------------------------|
| **Module** | **`snd_soc_pcm6240`** (in-kernel backport) | **`snd_soc_tac5x1x_taa5412`** (TI OOT) |
| **Firmware** | **`/lib/firmware/taa5412-i2c-1-1dev.bin`** required | Register init in driver (no pcm6240 blob) |
| **I²C driver name** | **`pcm6240`** | **`tac5x1x-codec`** |
| **Check** | **`lsmod \| grep pcm6240`** | **`lsmod \| grep tac5x1x_taa5412`** |

**Cabin loop (TAC5301 @ 0x50, SAI6)** is always a **separate** chip, driver, and ALSA device — never conflate with **`driver_mic`**.

---

## Mic input connectivity (product spec ↔ BSP)

**Control:** **I²C2**, slave address **0x51** (`taa5412@51` on **`&i2c2`** in **`imx8mm-jaguar-dt510.dts`**).

**Digital audio (`&sai5`):** Product specification maps these **i.MX8MM** mux options — they match BSP **`pinctrl_sai5_taa5412`** row‑for‑row:

| i.MX8MM IOMUX option | SAI function | Signal / notes |
|---------------------|--------------|----------------|
| **`MX8MM_IOMUXC_SAI5_RXD1_SAI5_TX_SYNC`** | **SAI5 TX Frame Sync** | LRCK / FS — CPU master drives frame sync toward codec (**BSP:** **`IMX8MM_PAD_I2S_FRAME_SYNC_EXT`** = SSOT **0x1916**). |
| **`MX8MM_IOMUXC_SAI5_RXC_SAI5_RX_BCLK`** | **SAI5 RX Bit Clock** | **BCLK** — CPU master (**BSP:** **`IMX8MM_PAD_GPIO_STD`** = SSOT **0x116** — *not* **`IMX8MM_PAD_SAI_DEFAULT`** EVK recipe **0xd6**). |
| **`MX8MM_IOMUXC_SAI5_RXD3_SAI5_TX_DATA0`** | **SAI5 TX Data 0** | Host→codec serial data (**BSP:** **`IMX8MM_PAD_GPIO_STD`**). |
| **`MX8MM_IOMUXC_SAI5_RXD0_SAI5_RX_DATA0`** | **SAI5 RX Data 0** | Codec→host ADC data (**BSP:** **`IMX8MM_PAD_GPIO_STD`**). |

**Sideband GPIO:** **`MX8MM_IOMUXC_SAI1_TXD6_GPIO4_IO18`** — **GPIO4_IO18**, product description **configurable GPIO connected to codec**. **`taa5412@51`** applies **`pinctrl_taa5412_codec_gpio`** (**`IMX8MM_PAD_GPIO_STD`**) so mux + pad electricals match SSOT **`BOARD_InitPins`**.

**Optional DT still TBD:** **`reset-gpios`**, **`interrupts`** on **`GPIO4_IO18`** once schematic polarity / net behaviour are fixed (**TI / EE**).

SSOT (**`docs/reference/dt510-ollie-tool-generated/pin_mux.dts`**): **`SAI5_RXC`**, **RXD0**, **RXD3** → **`0x00000116`**; **`SAI5_RXD1`** → **`0x00001916`**; **`SAI1_TXD6`** → **`GPIO4_IO18`**, **`0x00000116`**.

---

## Friendly name

| Name | Direction | Use |
|------|------------|-----|
| **`driver_mic`** | **Capture only** (`arecord`) | **Stereo** capture — **IN1 + IN2** when the PCM exposes **two** logical ADC channels (**`-c 2`**). Playback on these aliases is **`null`** (**`asym`**) so **`aplay`** does not open the Mic card. |
| **`driver_mic_in1`** | Capture only | **Mono** — **ALSA channel 0** only (= hardware **IN1** per SSOT mapping — confirm on bench). |
| **`driver_mic_in2`** | Capture only | **Mono** — **ALSA channel 1** only (**IN2**). |
| **`driver_mic_slot0`** | Capture only | Alias of **`driver_mic_in1`** (IEC-style slot naming, parallel to **`tannoy_slot*`**). |
| **`driver_mic_slot1`** | Capture only | Alias of **`driver_mic_in2`**. |
| **`ctl.driver_mic`** | — | **`amixer -D driver_mic …`** (same TI controls as **`hw:taa5412codec`**). |
| **`ctl.driver_mic_in1`** / **`ctl.driver_mic_in2`** | — | Same mixer card (**optional** convenience names). |
| **`ctl.driver_mic_slot0`** / **`ctl.driver_mic_slot1`** | — | Same (**optional** slot naming). |

Raw device: **`pcm._taa5412_hw`** → **`hw:taa5412codec`**, **device 0** (internal).

**Sample rate:** **`&sai5`** uses **48 kHz family** clocks (same PLL story as tannoy **SAI1** and driver speaker **SAI3**). Product capture PCMs (**`driver_mic`**, **`driver_mic_in1`**, **`driver_mic_in2`**, slot aliases) use **`_taa5412_48`** (`type rate` → **48000** on **`_taa5412_hw`**) with outer **`plug` `slave.rate 48000`** — mirror **`tannoy_*`** / **`driver_speaker`**. Apps may request **44100** or **22050**; the chain resamples before **SAI5** opens. Raw **`hw:taa5412codec`** at non‑48 kHz rates may fail with **`failed to derive required … rate`** in **`dmesg`**.

**AVM (DT510 production):** **`driver_input_device = driver_mic_in1`** in **`vix-apps/AVM/config/config.txt`** (single wired IN1). Use **`driver_mic`** for stereo IN1+IN2 lab capture.

**Not driver mic:** **`driver_speaker`** / **`aplay`** → **TAS2563 on `&sai3`** — see **`docs/DT510-TAS2563-DRIVER-SPEAKER-ALSA.md`**. That path does **not** clock **SAI5**.

---

## Commands

```sh
arecord -D driver_mic -f S16_LE -c 2 -r 48000 -d 3 /tmp/driver-mic-stereo.wav
arecord -D driver_mic_in1 -f S16_LE -c 1 -r 48000 -d 3 /tmp/driver-mic-in1.wav
arecord -D driver_mic_in2 -f S16_LE -c 1 -r 48000 -d 3 /tmp/driver-mic-in2.wav
# Slot aliases (same as in1/in2): driver_mic_slot0 | driver_mic_slot1
amixer -D driver_mic scontrols
```

**Channel count:** On **DT510**, hardware SSOT is **two differential microphone inputs — IN1 and IN2**. Treat **`-c`** / routing as **hardware + driver + firmware**, not DTS alone.

**Smoke script (when installed):** **`sudo dt510-taa5412-capture-check.sh`** — detects Path A or Path B; see **`board-scripts`**.

**Cab acoustic reference (Michael bench, 2026-06-11, Ollie sign-off):** Default `Ollie-WhatsApp-v2-boosted.mp4` @ **80%** laptop sink (`USE_ORIGINAL_STIM=1` default; XPS crackle accepted) — **`vix-apps/AVM/scripts/dt510-driver-mic-reference-playback-test.sh`**; see **`vix-apps/lab-artifacts/driver-mic-ref/README.md`**.

---

## Michael bench — scoping SAI5 (read this first)

### What clocks SAI5

| Action | SAI | Expected on scope |
|--------|-----|-------------------|
| **`arecord -D driver_mic …`** (leave running) | **`&sai5`** → TAA5412 | **BCLK** on **`SAI5_RXC`**, **LRCK/FS** on **`SAI5_RXD1`/`TX_SYNC`**, ADC data on **`SAI5_RXD0`** |
| **`aplay -D driver_speaker …`** | **`&sai3`** → TAS2563 | **SAI3** pins only — **does not drive SAI5** by itself |
| Idle (no **`arecord`** on **`driver_mic`**) | **`&sai5`** | **No BCLK/LRCLK** — normal **`fsl-sai`** gating |

Scoping **during active `arecord -D driver_mic`** is the correct procedure. **`aplay`** on the driver speaker alone is **not** a substitute for **`arecord`**.

**pcm6240 (Path A) bench note (targets 425–437):** On some **`snd_soc_pcm6240`** images, **`arecord -D driver_mic`** alone showed **zero SAI5 BCLK/LRCLK** on MSO while the stream appeared open; **parallel `aplay -D driver_speaker`** could restore clocks. **Target 438** (after pcm6240 **`0004`**) captures **record-only** with **non-silent WAV** and **SD edges on MSO** without parallel playback — but **clock frequencies still fail** MSO pass criteria (see § Bring-up progress). Lab scripts still default **`PARALLEL_APLAY=1`** where noted for older images and regression comparison.

### Confirm the stream is really open

In a second shell **while `arecord` runs**:

```sh
grep taa5412 /proc/asound/cards
cat /proc/asound/card*/pcm0c/sub0/hw_params   # must NOT say "closed"
sudo grep sai5 /sys/kernel/debug/clk/clk_summary | head -5
```

### Ranked causes when **no SAI5 clocks even during `arecord`**

1. **No ALSA card / deferred probe** — **`grep taa5412 /proc/asound/cards`** empty; **`dmesg`:** **`sound-taa5412` deferred**, **`&micfil`** pin conflict, or **`30050000.sai` probe `-EINVAL`** (historically **`fsl,sai-asynchronous`** + **`fsl,sai-synchronous-rx`** together — fixed in current DTS by **`/delete-property/ fsl,sai-asynchronous`**).
2. **`arecord` failed or wrong device** — used **`driver_speaker`**, **`tannoy_*`**, or **`aplay`** instead of **`arecord -D driver_mic`**; or capture exited before scope trigger.
3. **Wrong probe balls** — must match § Mic input connectivity (**`SAI5_RXC`**, **`SAI5_RXD1`**, **`SAI5_RXD0`**), not SAI3/TAS2563 or SAI1/TAS6424 nets.
4. **SAI5 up in kernel but codec ASI off (software)** — stream opens, **`sai5` clk enabled** in **`clk_summary`**, scope still quiet or **`arecord`** all zeros. Check **`PASITXCH1` (page 0 reg `0x1e`) bit 5** during capture — want **1** (e.g. value **`0x20`**+). **0** = TI ASI TX path not armed (Path B DAPM — see **`0003-lore-dapm-routes-taa5412.patch`**; factory **421** had stale OOT sstate).
5. **pcm6240 Path A — arecord-only MSO dead** — on **425+** with **`pcm6240`**, try **parallel `aplay -D driver_speaker`** during **`arecord -D driver_mic`** (see § What clocks SAI5 pcm6240 exception). Lab: **`PARALLEL_APLAY=1`** in **`scripts/lab/dt510-taa5412-pcm6240-i2c-test.sh`**.

```sh
# During running arecord (needs debugfs + sudo):
sudo grep -E '^(001e|0076):' /sys/kernel/debug/regmap/1-0051/registers
```

---

## I²S / **SAI5** — expected signals (hardware debug)

**Stack reference:** **`sound-taa5412`** sets **`frame-master`** and **`bitclock-master`** on **`&sai5`**. CPU drives **BCLK** and **frame sync**; codec returns ADC data on **RX data**.

**Clock gating:** BCLK/LRCLK appear **only while a capture PCM on this card is open**. Idle **SAI5** is expected dead on a scope.

### **`&sai5` device tree (current BSP)**

In **`imx8mm-jaguar-dt510.dts`**:

- **`/delete-property/ fsl,sai-asynchronous`** — NXP EVK leaves this on **`&sai5`**; remove inherited async so **`fsl,sai-synchronous-rx`** is valid ( **`fsl,sai-asynchronous`** + **`fsl,sai-synchronous-rx`** together → **`fsl_sai_probe` → `-EINVAL`**, card deferred — early **`lmp-350`**).
- **`fsl,sai-synchronous-rx`** — BCLK on **`SAI5_RXC`**, LRCK on **`SAI5_TX_SYNC`**: Rx is bit-clock master during **`arecord`**, Tx follows for frame sync. Kernel **0028** mirrors **RCR2/RCR4/RCR5 → TCR2/TCR4/TCR5** from regmap reads on capture, prefers TDM **slots×width** for BCLK, clears stale **bclk_ratio**, enables **Tx TERE** on capture trigger. MSO pass: LRCLK **~48 kHz**, BCLK **~3.072 MHz**, ratio **~64**.
- **`sound-taa5412` CPU DAI:** **`dai-tdm-slot-num = <2>`**, **`dai-tdm-slot-width = <32>`** — 48 kHz stereo **64 BCLK/LRCLK** (S16 payload in 32-bit I2S slots; not Michael’s bare 16-bit sample formula).
- **`assigned-clock-rates = <12288000>`**, **`AUDIO_PLL1_OUT`**, **`fsl,sai-mclk-direction-output`**.

**Pinmux (`pinctrl_sai5_taa5412`):**

| Pad | SAI role | Notes |
|-----|----------|--------|
| **`SAI5_RXC`** | **`SAI5_RX_BCLK`** | BCLK — **`IMX8MM_PAD_GPIO_STD`** (**SSOT `0x116`**) |
| **`SAI5_RXD1`** | **`SAI5_TX_SYNC`** | LRCK/FS — **`IMX8MM_PAD_I2S_FRAME_SYNC_EXT`** (**SSOT `0x1916`**) |
| **`SAI5_RXD0`** | **`SAI5_RX_DATA0`** | Codec → SoC ADC data |
| **`SAI5_RXD3`** | **`SAI5_TX_DATA0`** | SoC → codec (confirm vs schematic) |

**No dedicated SAI5 MCLK pad** on this mux — link is **BCLK + LRCLK + data** (cf. TAC5301 **BCLK-only** narrative on **`&sai6`**).

### Michael BCLK formula vs BSP target (48 kHz **`arecord -D driver_mic`**)

| Basis | Formula | BCLK @ 48 kHz | Notes |
|-------|---------|---------------|--------|
| **Michael (sample bits)** | **`LRCLK × bits_per_sample × channels`** = 48 kHz × 16 × 2 | **1.536 MHz** | Correct for **16-bit sample words** on the wire if the link used no slot padding. |
| **BSP / TI I2S (this DT)** | **`LRCLK × dai-tdm-slot-num × dai-tdm-slot-width`** = 48 kHz × 2 × 32 | **3.072 MHz** | **`S16_LE`** PCM still uses **32-bit I2S slots** per **`sound-taa5412`** — **64 BCLK per LRCLK** frame. MSO pass criteria use this row. |
| **Wrong (TCR≠RCR mirror)** | e.g. 48 kHz × **128** | **6.144 MHz** | Targets **430–438**: BCLK **~6.15 MHz**, LRCLK **~64–84 kHz**, ratio **~73–96** — **TCR2≠RCR2**, **TCR4≠RCR4** when **0028** mirror / **`hw_params`** hunks incomplete on dt510 kernel. |

**LRCLK target:** **48 kHz** toggle on **`SAI5_RXD1` / TX_SYNC** (one frame edge pair per stereo frame).

**Register check during capture:** **`TCR2` = `RCR2`**, **`TCR4`/`TCR5` = `RCR4`/`RCR5`** (requires **0028 v4** on dt510 tree), **`TCR4` bit FSD_MSTR** set; **`PASITXCH1` (0x1e) bit 5 = 1** for TI ASI TX.

### Codec ASI — **32-bit slots @ 48 kHz** (SSOT)

**Default link (BSP):** **`sound-taa5412`** + **`&sai5`** program **2 × 32-bit slots** @ **48 kHz** → **BCLK = 3.072 MHz**, **LRCLK = 48 kHz**, **64 BCLK/LRCLK**. **`arecord -D driver_mic -f S16_LE`** is valid: PCM is 16-bit samples inside **32-bit I2S slots**.

**Michael `taa5412-registers-michael.conf`** programs **power / micbias only** (`0x02`, `0x78`, page‑1 `0x73`) — **not** ASI format, word length, or **`PASITX*`** slot map.

**BSP `taa5412-1dev-reg.json` / `taa5412-i2c-1-1dev.bin` (Path A):** **`PRE_POWER_UP`** programs **Michael-aligned power** (`0x02` **VREF = `0x03`**, **`0x78` PWR = `0xa0`**, page‑1 **`0x73` MICBIAS = `0xd0`**), **IN1+IN2 channel enable** (`0x76` **CH_EN = `0xc0`** — ADC1+2 only), AC coupling (`0x50`/`0x55`/`0x5a`/`0x5e`), and **digital gain defaults** (**`0x52` Ch1 Digi = `0xf0` (240, +39.5 dB)**, **`0x53` Ch1 Fine = `0x80` (8)**, Ch2–4 Digi **0**, Fine **`0x80`**). Production uses **240**, not **255** — full scale clips on the DT510 mic path; **220** was an earlier bench step. The spurious **`0x42=0x10`** write was removed (wrong CH2 analog map on TAA5412). Still **does not write** **`0x1a` (`PASI0`)**, **`0x1e`/`0x1f` (`PASITXCH1/2`)** — driver **`0004`**. Boot backup: **`taa5412-init`** systemd oneshot (**`alsa-state`**, DT510) re-applies **`amixer -D driver_mic`** **`Ch1 Digi` / `Ch1 Fine`** (**240** / **8**) after probe.

**Bench I2C apply:** **`taa5412-registers-michael.conf`** is optional when regbin + **`taa5412-init`** are on the image; keep for A/B compare or pre-regbin factory targets.

| Reg (page 0) | Role | TI / driver encoding (tac5x1x family) |
|--------------|------|----------------------------------------|
| **`0x1a` `PASI0`** | ASI format + **word length** | Bits **7:6** format: **I2S = `0x40`**, TDM = `0x00`. Bits **5:4** length: **16 = `0x00`**, 20 = `0x10`, 24 = `0x20`, **32 = `0x30`**. **I2S + 32-bit → `0x70`**. |
| **`0x1e` `PASITXCH1`** | Ch1 TX slot + **ASI_TX** | Bits **4:0** slot index; **bit 5** = **ASI_TX enable** (must be **1** during **`arecord`**). |
| **`0x1f` `PASITXCH2`** | Ch2 TX slot + **ASI_TX** | Same; I2S stereo often **slot 0 / slot 16** when driver sets slot positions. |

**Bench decode:** **`dt510-taa5412-i2c-registers-dump.sh`** prints **`word_len_idx`** = **`(PASI0 >> 4) & 3`** (0→16b … 3→32b per table above).

### Ch1 Digi / PRE_POWER_UP on capture startup

**Symptom (target 526+, 2026‑06‑11):** Pre-stream **`amixer -D driver_mic`** or **`i2cset`** on **`0x52` (Ch1 Digi)** appears ignored — gain only changes if set **after** **`arecord`** is already running. **`Ch1 Digi`** readback snaps back to regbin default (**240 / `0xf0`**) when the capture stream opens.

**Root cause:** **`pcm6240-lmp/0003-asoc-pcm6240-capture-startup-pre-power-up.patch`** adds **`pcmdevice_startup`** → **`pcmdevice_mute(unmute)`** on every capture open. Unmute replays the full firmware **`PRE_POWER_UP`** block from **`taa5412-i2c-1-1dev.bin`**, including **`0x52=0xf0`**. **`0004-asoc-pcm6240-asi-tx-pasi0-on-capture.patch`** still called mute before ASI enable, so the overwrite persisted.

**Fix (BSP, not yet on factory image):** **`pcm6240-lmp/0005-asoc-pcm6240-skip-pre-power-up-on-capture-startup.patch`** — capture **`startup`** runs **`pcmdevice_asi_capture_enable`** only (**0004**); no **`PRE_POWER_UP`** replay on open. **`shutdown`** still calls **`pcmdevice_mute`** + ASI disable for power-down.

| Patch | Role |
|-------|------|
| **`0003-asoc-pcm6240-capture-startup-pre-power-up.patch`** | Original capture startup/shutdown hooks; mute on open (superseded for gain by **0005**) |
| **`0004-asoc-pcm6240-asi-tx-pasi0-on-capture.patch`** | **`PASI0=0x70`**, **`PASITXCH1/2` ASI_TX** on capture |
| **`0005-asoc-pcm6240-skip-pre-power-up-on-capture-startup.patch`** | Skip mute/**`PRE_POWER_UP`** on capture open |

**Lab workaround (images without `0005`):** Apply **`Ch1 Digi` / `Ch1 Fine`** **~0.5 s after** **`arecord`** starts — **`MIC_GAIN_AFTER_STREAM_SECS`** in **`dt510-driver-mic-reference-playback-test.sh`**; helper **`dt510-taa5412-amixer-gain.sh`** (defaults **240** / **8**). Post-stream **`amixer`** also works for one-off tests.

**Verification:**

1. **Without `0005`:** `amixer -D driver_mic sset 'TAA5412 i2c1 Dev0 Ch1 Digi Volume' 200` then `arecord -D driver_mic_in1 …` — readback returns **240** at stream open; peak unchanged vs default.
2. **Without `0005`:** Start **`arecord`**, then **`dt510-taa5412-amixer-gain.sh`** — readback **200** sticks; WAV peak rises.
3. **With `0005`:** Pre-stream **`amixer`** / **`i2cget -y 1 0x51 0x52`** value survives **`arecord` open**; **`MIC_GAIN_AFTER_STREAM_SECS=0`** OK in reference playback script.
4. Regression: **`arecord -D driver_mic`** still arms ASI (**`PASITXCH1` bit5**, **`PASI0=0x70`**) — **0004** path unchanged.

**Live bench (target 438, Path A `pcm6240`, 2026‑05‑26, during `arecord -D driver_mic`):** **`PASITXCH1=0x20`** (ASI_TX bit5 **on** — pcm6240 **`0004`**); **`PASI0=0x70`** (I2S + 32-bit). **Non-silent WAV** (peak **~387**), **SD edges** on MSO. **SAI5 clocks still wrong:** BCLK **~6.15 MHz**, LRCLK **~84 kHz**, ratio **~73** — **`TCR2≠RCR2`**, **`TCR4≠RCR4`** (kernel **0028** mirror / **`hw_params`** hunk still incomplete on dt510 tree).

**Target 438 investigation (2026‑05‑26) — quiet level + ch1 silent:**

| Symptom | Root cause | Evidence |
|---------|------------|----------|
| Peak **~387** (~**−38 dBFS**) regardless of speaker DVC | **Default `Ch1 Digi Volume` = 161/255** on TAA5412 — not speaker path | `amixer -D driver_mic`: Ch1 Digi=161; Ch1 Digi **255** → peak **32767**; Ch1 Digi **0** → silent. Speaker **`Digital Volume Control`** does not change mic level (expected). |

| **ch1 always silent**, ch0 only | **`pcm6240` `0004` enables PASITXCH1 only** — **`PASITXCH2=0x01`** (slot 1, **ASI_TX off**) | I2C during capture: **CH1=0x20**, **CH2=0x01**; manual **PASITXCH2=0x30** → ch1 peak **~12500**; reset **0x01** → ch1 **0** again. **0x21** (ASI_TX on slot 1) still silent — need **slot 16** (**0x30**), same as tac5x1x **426**. |
| Regmap vs I2C | Regmap cache **stale** for **0x1f** on pcm6240 | Regmap **001f: 01** while **i2cget 0x1f** reads **0x30** — use **`i2cget`** or dump script I2C path for PASITXCH2. |

**Fix:** extend **`pcm6240-lmp/0004`** to write **`PASITXCH2=0x30`** on capture startup (paired with **`0005`** tac5x1x behaviour). Lab gain: tune **`TAA5412 i2c1 Dev0 Ch1 Digi Volume`** (and Ch2 when stereo matters) — e.g. **200** for ~−19 dBFS without clipping.

**Codec-side (Path A):** **`pcm6240-lmp/0004`** sets **`PASITXCH1` ASI_TX** and **`PASI0=0x70`** on capture — firmware **`PRE_POWER_UP`** alone was insufficient; **must also set `PASITXCH2=0x30`** for stereo ch1. Path B equivalent: **`kernel-module-tac5x1x-ti-taa5412/0005`** (both PASITXCH1/CH2 ASI_TX).

---

## Bring-up progress (factory targets 430–438)

**Bench:** `fio@192.168.2.205` · MSO on `ajlennon@192.168.2.10` · Path A **`snd_soc_pcm6240`**. Consolidated log (older per-iteration notes in **`lab-artifacts/sai5-clock-iteration-*.md`** point here).

### Factory / BSP timeline

| Target | BSP SHA | Outcome |
|--------|---------|---------|
| **430** | `f59f93e` | **0028 v2** partial: RCR2=/4 but TCR2=/2 → BCLK **~6.15 MHz**, LRCLK **~64 kHz**, ratio **~96**. SD edges on MSO; clocks fail pass. |
| **431** | `175afb3` | **Regression:** **`!sai->is_consumer_mode`** reintroduced (array used as scalar) → mirror/Tx TERE never run → **no BCLK/LRCLK**, **PASITX=0**, silent WAV, MSO fail. |
| **432** | `7fefb4a` | Restore **`is_consumer_mode[tx]`** — **CI fail:** corrupt **0028** patch (`corrupt patch at line N`). |
| **433** | `bf6bf2c` | **0028 applies** at build; clocks still wrong — **TCR≠RCR**, BCLK **~6.16 MHz**, LRCLK **~76.8 kHz**, **PASITX=0**, silent capture. |
| **434** | `af31200` | **0028 v3** regmap mirror helper landed; **`hw_params`** hunk **never applied** (wrong anchor — NXP-only context). Same clock symptom. |
| **435–437** | — | **pcm6240 `0004`** patch corrupt → repeated **CI fail** (`do_patch` hunk/orphan context). |
| **438** | `7fdb47a` | **`0004` fixed** — **ASI TX works**, **record-only audio YES** (WAV peak **~387**), **SD edges** on MSO. **Clocks still fail MSO:** BCLK **~6.15 MHz**, LRCLK **~84 kHz**, ratio **~73**; **TCR2≠RCR2**, **TCR4≠RCR4**. |
| **439** | *(planned)* | **0028 v4** — complete mirror + **`hw_params`** on **dt510** kernel tree; target **48 kHz / 3.072 MHz / ratio 64**. |
| **526+** | — | **Ch1 Digi pre-stream gain ignored** — **`pcm6240` `0003`** replays regbin **`PRE_POWER_UP`** on capture open (see § Ch1 Digi / PRE_POWER_UP). |
| **Next factory target** | *(BSP pin pending)* | **`pcm6240-lmp/0005`** — capture startup ASI only; pre-stream **`amixer`** / **`i2cset`** on **`0x52`** sticks. |

### What works on target 438 (current bench)

- **`arecord -D driver_mic`** without parallel **`aplay -D driver_speaker`**
- **`PASITXCH1=0x20`**, **`PASI0=0x70`** (I2S 32-bit slots)
- **Non-silent WAV** and **SD activity** on MSO during capture
- **Path A `pcm6240`** stack (factory subscriber override — not tac5x1x OOT on this line)

### Still open

1. **SAI5 clocks** — LRCLK **48 kHz**, BCLK **3.072 MHz**, ratio **64** (Michael / BSP SSOT). Requires **0028 v4** on top of **438**.
2. **Phase B** — Michael I2C register compare after clocks pass (baseline from target **426** tac5x1x; see **`lab-artifacts/taa5412-michael-compare-20260526.md`** appendix).
3. **MSO automation pass criteria** — **`scripts/lab/dt510-sai5-clock-eval.py`**: LRCLK **48 kHz ±2%**, BCLK **3.072 MHz ±5%**, ratio **64 ±5%**; also checks **`pasitx_bit5`**, WAV peak **≥200**, SD edges.

### Michael clock guidance (pass criteria)

| Signal | Target | Formula |
|--------|--------|---------|
| **LRCLK** (word clock / FS on **`SAI5_RXD1`**) | **48 kHz** | Stereo frame rate for **`arecord -D driver_mic -r 48000`** |
| **BCLK** (on **`SAI5_RXC`**) | **3.072 MHz** | **LRCLK × 32 bits × 2 channels** (32-bit I2S slots — matches **`dai-tdm-slot-num=2`**, **`dai-tdm-slot-width=32`**) |
| **BCLK/LRCLK ratio** | **64** | Not **96** (TCR2 half of RCR2) or **~73** (438 symptom) |

During capture, **`TCR2=RCR2`**, **`TCR4/TCR5=RCR4/RCR5`**, **`TCR4` FSD_MSTR** set, **`PASITXCH1` bit 5 = 1**.

### Key root causes learned

| Issue | Lesson |
|-------|--------|
| **`is_consumer_mode`** | **`is_consumer_mode[tx]`** — not a scalar pointer; **`!sai->is_consumer_mode`** silently skips mirror (431, 425–429). |
| **Patch anchors** | Hunks must apply on the **dt510** unpacked kernel after prior **`SRC_URI`** patches — not NXP-only symbols absent from LmP tree (434 **`hw_params`** hunk). |
| **PASITX / ASI** | Firmware **`PRE_POWER_UP`** does not arm **`PASITX` bit 5**; pcm6240 needs explicit **`0004`** (438). |
| **Ch1 Digi on open** | **`0003`** mute on capture startup replays regbin (**`0x52`**) — **`0005`** skips **`PRE_POWER_UP`** on open; ASI still from **`0004`**. |
| **Sync-Rx capture** | With **`fsl,sai-synchronous-rx`**, **TCR2/TCR4** must mirror **RCR2/RCR4** or BCLK doubles and LRCLK drifts (430, 433, 438). |
| **Patch hygiene** | Run **`kernel-patch-lint.sh`** before BSP commit — corrupt **0028** / **0004** burned CI on **432**, **435–437**. |

### Tooling

- **`meta-dynamicdevices-bsp/scripts/kernel-patch-lint.sh`** (BSP **`8c94d0a`**) — structure lint; **`--dry-run-apply`** against **`VIXDT_KERNEL_SRC`** before factory push.
- Workspace rule **`memory-vixdt-kernel-patch-lint-before-commit.mdc`** — mandatory before BSP patch commits.
- Lab: **`scripts/lab/dt510-sai5-mso-remote-capture.sh`**, **`dt510-sai5-clock-eval.py`**, **`dt510-taa5412-pcm6240-i2c-test.sh`**.

### Earlier bench (pre-430)

| When | Observation |
|------|-------------|
| **2026‑05‑16** (pre sync-Rx DT) | **`arecord` running:** BCLK present, **FSYNC dead**, data idle — partial SAI master |
| **425–429** | **`is_consumer_mode`** bug → BCLK **~12.29 MHz**, LRCLK **~22 kHz** (ratio **~273**); stale **TCR4/TCR5** without mirror |

---

## Related

- **`docs/DT510-HARDWARE-AUDIT-CHECKLIST.md`** (TAA5412 rows + § Codec notes)
- **`docs/DT510-TAS2563-DRIVER-SPEAKER-ALSA.md`** (**`driver_speaker`** — **SAI3**, not SAI5)
- **`meta-subscriber-overrides/docs/DT510-HARDWARE-BRINGUP.md`** § TAA5412
- Workspace bench log **`lab-artifacts/taa5412-michael-compare-20260526.md`** (Michael regbin / I2C vs factory, **`taa5412-init`**)

*Last updated: **2026‑06‑11** — § Ch1 Digi / PRE_POWER_UP (**pcm6240 `0005`** pending next factory target); bring-up through **438**; **0028 v4** (439) pending for SAI5 clock pass.*
