# DT510 — TAS2563 driver-speaker ALSA

**Scope:** **`imx8mm-jaguar-dt510`**. **`alsa-state`** installs **`imx8mm-jaguar-dt510/asound.conf`** plus **`tas2563-init`** (systemd **`tas2563-init.service`**, alongside **`tas6424-init`**).

**Hardware:** TI **TAS2563‑Q1** (**`tas2563@4c`**, **`sound-tas2563`**). **`simple-audio-card,name = "tas2563-audio"`** → ALSA card short id **`tas2563audio`**.

**Digital link:** **`&sai3`**, **Profile‑8‑style CPU TDM** — **`dai-tdm-slot-num = <4>`**, **`dai-tdm-slot-width = <32>`** (see **`imx8mm-jaguar-dt510.dts`**). Codec **`ti,channels = <1>`** (mono product path) with **`ti,left-slot = <0>`**, **`ti,right-slot = <1>`** (slot naming for the TDM frame / TI driver — not the TAS6424 “Tannoy” pair).

**Companion (class‑D passenger / cabin path):** [`DT510-TAS6424-TANNOY-ALSA.md`](DT510-TAS6424-TANNOY-ALSA.md).

---

## Friendly PCMs / controls

| Name | Role |
|------|------|
| **`drivers`** | Raw **`pcm`/`ctl`** on **`tas2563audio`** (**`hw`**) |
| **`driver_speaker`** | **`plug`** → **`drivers`** — **default-style** playback helper (formats/rates normalized) |
| **`driver_slot0` / `driver_slot1`** | **`route`** + **`plug`**: maps stream channel **0** to TDM IEC slot **0** or **1** (slave **`pcm._tas2563_tdm`**, **`channels 4`**) |
| **`driver_slots_lr`** | Stereo: **L→slot 0**, **R→slot 1** |

**Mixer:** **`amixer -D drivers`** (or **`hw:<card#>`** if the named ctl is missing).

The **TAS2781‑comlib** stack exposes **`Speaker Digital Volume`** (kernel index enum over **`tas2563_dvc_table`**). **`tas2563-init`** sets this from **`TAS2563_BOOT_DVC`** (**`204`** default in the script unless overridden — confirm level on bench).

---

## Commands

```sh
aplay -D driver_speaker /path/to.wav
amixer -D drivers scontrols
```

---

## Operational notes

- If **`pcm._tas2563_tdm`** (**`channels 4`**) fails to open (**`Invalid argument`** / **`Channels count not available`**), drop or edit the **`driver_slot*`** slaves for this board’s real **`hw_params`** (often the raw device is **not** a 4‑open PCM at the ALSA boundary). Prefer **`driver_speaker`** until channel count is confirmed with **`aplay -D hw:tas2563audio … -vvv`** or **`/proc/asound/card*/pcm*/`**.
- **Sentai:** uses a different **`/etc/asound.conf`** (**`pcm.spk`**, gadget paths). **DT510** keeps **TAS6424 (“Tannoy”)** plus **driver** overlays in **one** file — see header comments in **`asound.conf`**.

**Companion:** analogue loop codec — **`docs/DT510-TAC5301-AUDIO-LOOP-ALSA.md`** (**`audio_loop`**, **`aux`**).

*Last updated: 2026-05-06 — DT510 `alsa-state` bindings for **`driver_speaker`** + **`tas2563-init`**.*
