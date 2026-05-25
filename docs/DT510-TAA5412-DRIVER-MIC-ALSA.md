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

---

## Michael bench — scoping SAI5 (read this first)

### What clocks SAI5

| Action | SAI | Expected on scope |
|--------|-----|-------------------|
| **`arecord -D driver_mic …`** (leave running) | **`&sai5`** → TAA5412 | **BCLK** on **`SAI5_RXC`**, **LRCK/FS** on **`SAI5_RXD1`/`TX_SYNC`**, ADC data on **`SAI5_RXD0`** |
| **`aplay -D driver_speaker …`** | **`&sai3`** → TAS2563 | **SAI3** pins only — **does not drive SAI5** by itself |
| Idle (no **`arecord`** on **`driver_mic`**) | **`&sai5`** | **No BCLK/LRCLK** — normal **`fsl-sai`** gating |

Scoping **during active `arecord -D driver_mic`** is the correct procedure. **`aplay`** on the driver speaker alone is **not** a substitute for **`arecord`**.

**pcm6240 (Path A) bench exception (target 425+, 2026‑05):** On factory **`snd_soc_pcm6240`** images, **`arecord -D driver_mic`** alone may still show **zero SAI5 BCLK/LRCLK** on MSO while the stream appears open. Bench found that **parallel `aplay -D driver_speaker`** during capture can restore SAI5 clocks — even though **`driver_speaker`** is **SAI3/TAS2563**, not SAI5. Lab scripts default **`PARALLEL_APLAY=1`** in **`dt510-taa5412-pcm6240-i2c-test.sh`** and optional **`PARALLEL_APLAY=1`** in **`dt510-sai5-mso-remote-capture.sh`**. This quirk is **pcm6240-specific**; generic guidance above still applies for tac5x1x OOT and normal bring-up.

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
- **`fsl,sai-synchronous-rx`** — BCLK on **`SAI5_RXC`**, LRCK on **`SAI5_TX_SYNC`**: Rx is bit-clock master during **`arecord`**, Tx follows for frame sync. Kernel **0028** mirrors **RCR2→TCR2** (BCLK divider), **RCR4/RCR5→TCR4/TCR5** + **FSD_MSTR** (LRCLK on TX_SYNC), clears stale **bclk_ratio** when TDM slots are set. MSO target: BCLK **~3.072 MHz**, LRCLK **~48 kHz**, ratio **~64**.
- **`sound-taa5412` CPU DAI:** **`dai-tdm-slot-num = <2>`**, **`dai-tdm-slot-width = <32>`** — 48 kHz stereo **64 BCLK/LRCLK** (S16 in 32-bit I2S slots).
- **`assigned-clock-rates = <12288000>`**, **`AUDIO_PLL1_OUT`**, **`fsl,sai-mclk-direction-output`**.

**Pinmux (`pinctrl_sai5_taa5412`):**

| Pad | SAI role | Notes |
|-----|----------|--------|
| **`SAI5_RXC`** | **`SAI5_RX_BCLK`** | BCLK — **`IMX8MM_PAD_GPIO_STD`** (**SSOT `0x116`**) |
| **`SAI5_RXD1`** | **`SAI5_TX_SYNC`** | LRCK/FS — **`IMX8MM_PAD_I2S_FRAME_SYNC_EXT`** (**SSOT `0x1916`**) |
| **`SAI5_RXD0`** | **`SAI5_RX_DATA0`** | Codec → SoC ADC data |
| **`SAI5_RXD3`** | **`SAI5_TX_DATA0`** | SoC → codec (confirm vs schematic) |

**No dedicated SAI5 MCLK pad** on this mux — link is **BCLK + LRCK + data** (cf. TAC5301 **BCLK-only** narrative on **`&sai6`**).

### Lab timeline (Michael Hull)

| When | Observation |
|------|-------------|
| **2026‑05‑16** (pre sync-Rx DT fix) | **`arecord` running:** **BCLK present**, **FSYNC dead**, data idle — partial SAI master, LRCK pad/mode mismatch |
| **2026‑05 / target 430** | **0028 v2 (register proof):** RCR2=/4 but TCR2=/2 → BCLK **~6.15 MHz**; TCR5=0, TCR4 no **FSD_MSTR** → LRCLK **~64 kHz**, ratio **~96**. Fix: mirror **RCR2→TCR2**, **RCR4/5→TCR4/5** + **FSD_MSTR**, prefer TDM **slots×width** for BCLK, clear stale **bclk_ratio** |
| **2026‑05 / target 425–429** | **`arecord -D driver_mic`:** BCLK **~12.29 MHz**, LRCLK **~22 kHz** (ratio **~273** vs **64**) when kernel **0028** used **`!sai->is_consumer_mode`** (array pointer — mirror never ran). Fixed: **`is_consumer_mode[tx]`** + enable **Tx TERE** on capture trigger |
| **2026‑05 / target 425–428** | Earlier: LRCLK **~72–218 kHz** (stale **TCR4/TCR5** without mirror) — **0028 + sync-rx** after fix above |

---

## Related

- **`docs/DT510-HARDWARE-AUDIT-CHECKLIST.md`** (TAA5412 rows + § Codec notes)
- **`docs/DT510-TAS2563-DRIVER-SPEAKER-ALSA.md`** (**`driver_speaker`** — **SAI3**, not SAI5)
- **`meta-subscriber-overrides/docs/DT510-HARDWARE-BRINGUP.md`** § TAA5412

*Last updated: **2026‑05‑25** — SAI5 **0028 v2** sync-rx clock fix (RCR2→TCR2, FSD_MSTR, TDM BCLK); factory **430** register evidence.*
