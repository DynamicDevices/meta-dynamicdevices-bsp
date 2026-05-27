# DT510 — TAC5301‑Q1 analog ALSA (“audio_loop” / “aux”)

**Scope:** **`imx8mm-jaguar-dt510`**. Card from **`sound-tac5301`** / **`simple-audio-card,name = "tac5301-codec"`** → ALSA short id **`tac5301codec`** (hyphens stripped — confirm with **`grep tac5301 /proc/asound/cards`**).

**Roles (product naming):**

| Friendly name | Direction | Typical use |
|---------------|-----------|-----------|
| **`audio_loop`** | **Playback only** (`aplay`) | Analog **output** path wired for the **vehicle / cabin audio loop** (DAC side). **AVM onboard default:** **`passengers_output_device = audio_loop`** (passenger/group announcements into the analogue loop mix). Use **`tannoy_*`** (TAS6424) instead in **`AVM`** when PA horns—not the cabin loop—should carry the passenger channel (**`docs/DT510-TAS6424-TANNOY-ALSA.md`**). |
| **`aux`** | **Capture only** (`arecord`) | **Analog input** presently **unused / reserved as aux** — record here if wired later. |

**Implementation:** **`/etc/asound.conf`** **`type asym`** — **`playback.pcm`** / **`capture.pcm`** so apps get a clear **`Invalid argument`** if they **`arecord`** on **`audio_loop`** or **`aplay`** on **`aux`** (instead of silently sharing one logical bus).

---

## Mixer

**`audio_loop`** and **`aux`** share one codec card **`tac5301codec`**:

```sh
amixer -D audio_loop scontrols
amixer -D aux scontrols
```

Same controls either way (**`hw:`** **`tac5301codec`**).

---

## Commands

```sh
aplay -D audio_loop /path/to.wav
arecord -D aux -f S16_LE -c 1 -r 48000 -d 5 /tmp/aux.wav
speaker-test -D audio_loop -c 2 -t wav
```

**Boot / rate:** Codec link is **`&sai6`** **I²S**, **no MCLK** on this board — **48 kHz family** clocks like tannoy **SAI1**. Product PCMs **`audio_loop`** (playback) and **`aux`** (capture) use **`_tac5301_48`** (`type rate` → **48000** on **`_tac5301_hw`**) with outer **`plug` `slave.rate 48000`** — mirror **`tannoy_*`** / **`driver_speaker`**. Apps may pass **44100** WAVs to **`aplay -D audio_loop`**; the chain resamples before **SAI6** opens. Raw **`hw:tac5301codec`** at non‑48 kHz may **EINVAL** or log **`failed to derive required … rate`**.

---

## Related

Analog defaults / **`ti,out1-mono-*`** / **`ti,adc1-*`:** kernel **`10-dt510-tac5301-analog-dt-defaults.patch`**; engineering notes in **`docs/DT510-HARDWARE-AUDIT-CHECKLIST.md`** (codec section).

*Last updated: 2026-05-06 — friendly ALSA PCM/ctl aliases for DT510.*
