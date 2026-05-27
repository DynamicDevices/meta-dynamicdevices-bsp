# DT510 — TAS2563 driver-speaker ALSA

**Scope:** **`imx8mm-jaguar-dt510`**. **`alsa-state`** installs **`imx8mm-jaguar-dt510/asound.conf`** plus **`tas2563-init`** (systemd **`tas2563-init.service`**, alongside **`tas6424-init`**).

**Hardware:** TI **TAS2563‑Q1** (**`tas2563@4c`**, **`sound-tas2563`**). **`simple-audio-card,name = "tas2563-audio"`** → ALSA card short id **`tas2563audio`**.

**Digital link:** **`&sai3`**, **Profile‑8‑style CPU TDM** — **`dai-tdm-slot-num = <4>`**, **`dai-tdm-slot-width = <32>`** (see **`imx8mm-jaguar-dt510.dts`**). Codec **`ti,channels = <1>`** (**mono** — **one differential speaker**). DTS still carries **`ti,left-slot = <0>`**, **`ti,right-slot = <1>`** for TI slot bookkeeping on the frame; **friendly ALSA routes only expose one IEC slot** (**slot 0**, **`ti,left-slot`**) matching that physical output.

**Companion (class‑D passenger / cabin path):** [`DT510-TAS6424-TANNOY-ALSA.md`](DT510-TAS6424-TANNOY-ALSA.md).

---

## Friendly PCMs / controls

| Name | Role |
|------|------|
| **`drivers`** | Raw **`pcm`/`ctl`** on **`tas2563audio`** (**`hw`**) — **lab only** at non‑48 kHz rates |
| **`driver_speaker`** | **`plug`** @ **48 kHz** → **`_tas2563_48`** (**`rate`** → **`drivers`**) — **product playback** |
| **`driver_slot`** | **`plug`** @ **48 kHz** → **`route`** → **`_tas2563_tdm_48`** — mono → **IEC slot 0** |
| **`driver_out`** | Same **`route`** as **`driver_slot`** — schematic **OUT** naming only |
| **`ctl.driver_slot`** / **`ctl.driver_out`** | Same **`hw`** mixer card as **`ctl.drivers`** (**optional** **`amixer`** convenience names). |

**Mixer:** **`amixer -D drivers`** (or **`hw:<card#>`** if the named ctl is missing).

The **TAS2781‑comlib** stack exposes **`Speaker Digital Volume`** (kernel index enum over **`tas2563_dvc_table`**, **0–255**). **`tas2563-init`** sets this from **`TAS2563_BOOT_DVC`** (**`204`** default ≈ −20 dB).

**IMAGE 438+ (in-kernel `snd_soc_tas2562`):** control is **`Digital Volume Control`** (**0–110** dB steps). Boot default **`TAS2562_BOOT_DVC=110`** (lab PTT max). AVM **`driver_speaker_alsa_control`** should match; values **≤110** are applied directly, **>110** mapped from legacy 0–255 intent.

---

## Commands

```sh
aplay -D driver_speaker /path/to.wav
aplay -D driver_slot /path/to.wav     # IEC slot 0 (same audio route as driver_out)
aplay -D driver_out /path/to.wav
amixer -D drivers scontrols
```

---

## Operational notes

- **`&sai3`** uses **12.288 MHz** / **48 kHz family** (same PLL story as **SAI1** tannoy). **`aplay -D drivers -r 44100`** may fail with **`failed to derive required Tx rate: 2822400`** in **`dmesg`**. Use **`driver_speaker`**, **`driver_slot`**, or **`driver_out`** — they mirror **`tannoy_*`**: **`_tas2563_*_48`** + **`plug` `slave.rate 48000`**. **AVM** already uses **`driver_speaker`** at **48000**.
- If **`pcm._tas2563_tdm`** (**`channels 4`**) fails to open (**`Invalid argument`** / **`Channels count not available`**), drop or edit **`driver_slot`** / **`driver_out`** slaves for this board’s real **`hw_params`** — see **`aplay -D hw:tas2563audio … -vvv`** or **`/proc/asound/card*/pcm*/`**. Prefer **`driver_speaker`** until confirmed.
- **Sentai:** uses a different **`/etc/asound.conf`** (**`pcm.spk`**, gadget paths). **DT510** keeps **TAS6424 (“Tannoy”)** plus **driver** overlays in **one** file — see header comments in **`asound.conf`**.

**Companion:** analogue loop codec — **`docs/DT510-TAC5301-AUDIO-LOOP-ALSA.md`** (**`audio_loop`**, **`aux`**).

*Last updated: 2026-05-16 — single **`driver_slot`** / **`driver_out`** pair (mono OUT); removed **`driver_slot0`/`1`/`slots_lr`** helpers.*
