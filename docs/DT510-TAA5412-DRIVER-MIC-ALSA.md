# DT510 — TAA5412‑Q1 “Driver Mic” ALSA capture

**Scope:** **`imx8mm-jaguar-dt510`**, **`MACHINE_FEATURES`** **`taa5412`**, **`sound-taa5412`** with **`simple-audio-card,name = "taa5412-codec"`** → ALSA short id **`taa5412codec`** (hyphens stripped — confirm with **`grep taa5412 /proc/asound/cards`**).

**Hardware / stack:** TI **TAA5412‑Q1** (PCM6240 family) on **`&i2c2` `0x51`**, **`&sai5`**, **`snd_soc_pcm6240`**. **Required:** TI firmware **`taa5412-i2c-<n>-1dev.bin`** (typical DT510: **`i2c-1`** → **`/lib/firmware/taa5412-i2c-1-1dev.bin`**). **`&micfil` disabled** so **SAI5_RXC** is available. See checklist + **`meta-subscriber-overrides/docs/DT510-HARDWARE-BRINGUP.md`** § TAA5412.

---

## Mic input connectivity (product spec ↔ BSP)

**Control:** **I²C2**, slave address **0x51** (`taa5412@51` on **`&i2c2`** in **`imx8mm-jaguar-dt510.dts`**).

**Digital audio (`&sai5`):** Product specification maps these **i.MX8MM** mux options — they match BSP **`pinctrl_sai5_taa5412`** row‑for‑row:

| i.MX8MM IOMUX option | SAI function | Signal / notes |
|---------------------|--------------|----------------|
| **`MX8MM_IOMUXC_SAI5_RXD1_SAI5_TX_SYNC`** | **SAI5 TX Frame Sync** | LRCK / FS — CPU master drives frame sync toward codec (**BSP:** **`IMX8MM_PAD_I2S_FRAME_SYNC_EXT`**). |
| **`MX8MM_IOMUXC_SAI5_RXC_SAI5_RX_BCLK`** | **SAI5 RX Bit Clock** | **BCLK** — CPU master. |
| **`MX8MM_IOMUXC_SAI5_RXD3_SAI5_TX_DATA0`** | **SAI5 TX Data 0** | Host→codec serial data (**product spec** fourth I²S wire). |
| **`MX8MM_IOMUXC_SAI5_RXD0_SAI5_RX_DATA0`** | **SAI5 RX Data 0** | Codec→host ADC data. |

**Sideband GPIO:** **`MX8MM_IOMUXC_SAI1_TXD6_GPIO4_IO18`** — **GPIO4_IO18**, product description **configurable GPIO connected to codec**.

**BSP gap:** **`taa5412@51`** currently declares **`compatible`**, **`reg`**, **`#sound-dai-cells`**, **`status`** only — **no** **`reset-gpios`**, **`interrupts`**, or **`pinctrl`** entry for **`GPIO4_IO18`**. **`snd_soc_pcm6240`** supports optional **`reset-gpios`** (hardware reset pulse at probe) and optional **`interrupts`** when wired; if **`GPIO4_IO18`** gates reset, power‑down, or an IRQ strap required before **I²S** / ADC activity, bring‑up must add the correct binding once **polarity + net name** are confirmed on schematic (**TI datasheet / EE**).

SSOT pad SW_PAD for **`SAI1_TXD6 → GPIO4_IO18`** is **`0x116`** in **`docs/reference/dt510-ollie-tool-generated/pin_mux.dts`**.

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

If **`snd_pcm_hw_params`** shows **four** logical capture channels on this board, remap mono **`route`** **`slave.channels`** / **`ttable`** columns (keep **`driver_mic`** as full-stream **`plug`** until then).

---

## Commands

```sh
arecord -D driver_mic -f S16_LE -c 2 -r 48000 -d 3 /tmp/driver-mic-stereo.wav
arecord -D driver_mic_in1 -f S16_LE -c 1 -r 48000 -d 3 /tmp/driver-mic-in1.wav
arecord -D driver_mic_in2 -f S16_LE -c 1 -r 48000 -d 3 /tmp/driver-mic-in2.wav
# Slot aliases (same as in1/in2): driver_mic_slot0 | driver_mic_slot1
amixer -D driver_mic scontrols
```

**Channel count:** On **DT510**, hardware SSOT is **two differential microphone inputs — IN1 and IN2** (two analog mic channels into the codec). The **TAA5412 / PCM6240** silicon can still expose **more logical ADC slots** over **I²S** than those two nets use — treat **`-c`** / routing as **hardware + firmware + driver**, not DTS alone (checklist § TAA5412 notes **IN1/IN2**). Prefer validating capture channels against schematic + **`arecord`** HW params after firmware is correct.

---

## I²S / **SAI5** — expected signals (hardware debug)

If analog coupling / firmware look sane but **`arecord`** is still flat zeros, validate the **digital audio link** between **i.MX8MM `&sai5`** and **TAA5412**. Missing **BCLK**, **LRCK/FS**, or codec **SDOUT** on the PCB explains silence regardless of **`ADC_CHx_CFG0`**.

**Clock gating (normal on this stack):** **BCLK** is observed **only while a capture stream is open** (e.g. **`arecord -D driver_mic …`** running). With **no active PCM**, **`fsl,sai`** typically **idles/gates** the interface — **absence of BCLK when idle is not, by itself, a PCB fault.** Scope **FSYNC** and data **during** **`arecord`** the same way.

**Stack reference:** **`imx8mm-jaguar-dt510.dts`** — **`sound-taa5412`** (**`simple-audio-card`**) sets **`frame-master`** and **`bitclock-master`** on **`&taa5412_cpu_dai`** → **`&sai5`**. The **CPU drives bit clock and frame sync** toward the codec; the codec feeds **ADC serial data** back on the **RX data** pad.

**Pinmux (`pinctrl_sai5_taa5412`):**

| Pad / ball naming | SAI role | Notes |
|-------------------|---------|--------|
| **`SAI5_RXC`** | **`SAI5_RX_BCLK`** | Bit clock (**BCLK**) |
| **`SAI5_RXD1`** | **`SAI5_TX_SYNC`** | Frame sync / LRCK — BSP uses **`IMX8MM_PAD_I2S_FRAME_SYNC_EXT`** on this pad (same electrical framing recipe as **`pinctrl_sai1_tas6424`** / **`SAI1_TXFS`** — see DTS banner comment). Wrong pad electrical mode can produce **present-but-useless clocks**. |
| **`SAI5_RXD0`** | **`SAI5_RX_DATA0`** | Serial **ADC data into SoC** |
| **`SAI5_RXD3`** | **`SAI5_TX_DATA0`** | CPU-side **TX data** line muxed from **`RXD3`** — confirm against **schematic / TI slave-mode wiring** whether this net must toggle, tie, or N/C for your revision. |

**`&sai5` clocks:** **`assigned-clock-rates = <12288000>`**, parent **`AUDIO_PLL1_OUT`** — software intends **12.288 MHz** MCLK/internal reference consistent with **`fsl,sai-mclk-direction-output`** (same pattern as **`&sai3`** / **`&sai6`**).

**No dedicated package MCLK pad:** DTS banner documents **no separate `SAI5_MCLK` pin** on this mux — intended link is **BCLK + LRCK + data** (cf. **TAC5301** on **`&sai6`** **BCLK-only** narrative). If **TI or the schematic expects a free-running master clock** at a crystal frequency **independent** of **`SAI5`**, that net **does not exist** in this DT narrative. **Do not** mistake **idle** (PCM closed, **BCLK off**) for **broken wiring** — compare **during `arecord`** only.

**Bench procedure:**

1. Start **`arecord -D driver_mic …`** (leave running); probe **with stream open** — **BCLK / FSYNC / data are authoritative under capture**, not at idle.
2. Confirm **BCLK** frequency matches **`LRCK × slot × bits`** for your mode (**e.g.** **48 kHz × 64 × …** for classic **I²S** staging — verify against **`pcm6240`** DAI format actually negotiated).
3. Compare measured nets to **`docs/reference/dt510-ollie-tool-generated/pin_mux.dts`** (SSOT).

### Bench observation (**Michael Hull**, **2026‑05‑16**) — FSYNC + data idle despite **BCLK**

| Net | Observation |
|-----|----------------|
| **BCLK** | **Present while `arecord` is running** — **expected** (clocks gated when PCM closed; see **Clock gating** above). |
| **FSYNC** (LRCK / frame on **`SAI5_TX_SYNC`**) | **Not active** — **blocking**: codec framing never advances; explains flat **`arecord`** / zeros even when analogue path is sane. |
| **DOUT / DIN** (codec vs host naming; ↔ **`RX_DATA0`** / **`TX_DATA0`**) | **Not active** — **expected consequence** of missing FSYNC (no slot boundaries → no meaningful serial toggling). |

**BSP response:** **`imx8mm-jaguar-dt510.dts`** **`&sai5`** now sets **`fsl,sai-synchronous-rx`** (same idea as **`&sai3`** / **`imx8mm-jaguar-sentai.dts`**) so RX capture runs **synchronized with the TX clock domain** — hypothesis: FS muxed as **`TX_SYNC`** only toggles when that linkage is enabled. **Contrast:** **`&sai6`** deliberately omits **`fsl,sai-synchronous-rx`** (tac5301 probe **`-EINVAL`** with sync on **6.6** **`fsl,sai`**); if **`&sai5`** fails probe or audio regresses, **revert** synchronous RX and escalate with **`dmesg`**.

**Still validate HW:** continuity / probe **correct ball** per product § Mic input connectivity; pad **`IMX8MM_PAD_I2S_FRAME_SYNC_EXT`** vs stuck-low solder bridge.

---

## Related

- **`docs/DT510-HARDWARE-AUDIT-CHECKLIST.md`** (TAA5412 rows + § Codec notes)
- **`docs/DT510-TAS2563-DRIVER-SPEAKER-ALSA.md`** (**Driver** **playback**: smart amp **`driver_speaker`**)

*Last updated: **2026‑05‑16** — **BCLK only during `arecord`** documented (normal gating); Michael bench (**FSYNC/data idle**) + **`&sai5`** **`fsl,sai-synchronous-rx`**; **2026‑05‑06** — Mic input connectivity §; **`driver_mic_in*` / `driver_mic_slot*`** PCMs.*
