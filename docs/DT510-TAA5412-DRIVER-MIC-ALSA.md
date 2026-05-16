# DT510 — TAA5412‑Q1 “Driver Mic” ALSA capture

**Scope:** **`imx8mm-jaguar-dt510`**, **`MACHINE_FEATURES`** **`taa5412`**, **`sound-taa5412`** with **`simple-audio-card,name = "taa5412-codec"`** → ALSA short id **`taa5412codec`** (hyphens stripped — confirm with **`grep taa5412 /proc/asound/cards`**).

**Hardware / stack:** TI **TAA5412‑Q1** (PCM6240 family) on **`&i2c2` `0x51`**, **`&sai5`**, **`snd_soc_pcm6240`**. **Required:** TI firmware **`taa5412-i2c-<n>-1dev.bin`** (typical DT510: **`i2c-1`** → **`/lib/firmware/taa5412-i2c-1-1dev.bin`**). **`&micfil` disabled** so **SAI5_RXC** is available. See checklist + **`meta-subscriber-overrides/docs/DT510-HARDWARE-BRINGUP.md`** § TAA5412.

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

## Related

- **`docs/DT510-HARDWARE-AUDIT-CHECKLIST.md`** (TAA5412 rows + § Codec notes)
- **`docs/DT510-TAS2563-DRIVER-SPEAKER-ALSA.md`** (**Driver** **playback**: smart amp **`driver_speaker`**)

*Last updated: 2026-05-16 — per‑channel **`driver_mic_in*` / `driver_mic_slot*`** PCMs in **`imx8mm-jaguar-dt510/asound.conf`**.*
