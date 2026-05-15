# DT510 — TAA5412‑Q1 “Driver Mic” ALSA capture

**Scope:** **`imx8mm-jaguar-dt510`**, **`MACHINE_FEATURES`** **`taa5412`**, **`sound-taa5412`** with **`simple-audio-card,name = "taa5412-codec"`** → ALSA short id **`taa5412codec`** (hyphens stripped — confirm with **`grep taa5412 /proc/asound/cards`**).

**Hardware / stack:** TI **TAA5412‑Q1** (PCM6240 family) on **`&i2c2` `0x51`**, **`&sai5`**, **`snd_soc_pcm6240`**. **Required:** TI firmware **`taa5412-i2c-<n>-1dev.bin`** (typical DT510: **`i2c-1`** → **`/lib/firmware/taa5412-i2c-1-1dev.bin`**). **`&micfil` disabled** so **SAI5_RXC** is available. See checklist + **`meta-subscriber-overrides/docs/DT510-HARDWARE-BRINGUP.md`** § TAA5412.

---

## Friendly name

| Name | Direction | Use |
|------|------------|-----|
| **`driver_mic`** | **Capture only** (`arecord`) | Driver-facing **cabinet / operator microphone** path (ADC stream from **TAA5412**). Playback on this alias is **`null`** (**`asym`**) so **`aplay`** does not accidentally open the Mic card. |
| **`ctl.driver_mic`** | — | **`amixer -D driver_mic …`** (same hardware controls as **`hw:taa5412codec`**). |

Raw device: **`pcm._taa5412_hw`** → **`hw:taa5412codec`**, **device 0** (do not use from apps — treat as internal).

---

## Commands

```sh
arecord -D driver_mic -f S16_LE -c 4 -r 48000 -d 3 /tmp/driver-mic.wav   # ch count per product / driver
amixer -D driver_mic scontrols
```

**Channel count:** TAA5412 is a **4‑ch** ADC family; product may use **fewer** routed channels — negotiate with **`plug`** ( **`driver_mic`** already uses **`plug`** on capture) or trim **`-c`** / format to match drivers and wiring.

---

## Related

- **`docs/DT510-HARDWARE-AUDIT-CHECKLIST.md`** (TAA5412 rows + § Codec notes)
- **`docs/DT510-TAS2563-DRIVER-SPEAKER-ALSA.md`** (**Driver** **playback**: smart amp **`driver_speaker`**)

*Last updated: 2026-05-06 — **`driver_mic`** in **`imx8mm-jaguar-dt510/asound.conf`**.*
