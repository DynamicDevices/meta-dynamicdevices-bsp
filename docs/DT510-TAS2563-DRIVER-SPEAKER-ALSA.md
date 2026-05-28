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

**IMAGE 438+ (in-kernel `snd_soc_tas2562`):** **`Digital Volume Control`** (**0–110**) and **`Amp Gain Volume`** (**0–28**, ~0.5 dB/step from 8.5 dB).

**Power / production defaults (30 W per channel spec):** Boot and AVM use **`TAS2562_BOOT_DVC=100`**, **`TAS2562_BOOT_AMP_GAIN=20`**. Amp gain dominates analog power; keep **amp ≤20** for sustained play. **DVC 110 + amp 28** is **lab-debug only** (clips + ~90 W, far over spec). Sentai reference: DVC **82**, amp **20**.

AVM: **`driver_speaker_alsa_volume`**, **`driver_speaker_alsa_amp_gain`** (re-applied at AVM start / before driver play).

### Lab calibration (2026-05-28, Michael)

Michael swept driver cab audibility on bench with **Amp Gain fixed at 20** (30 W/channel target):

| Phase | DVC range | Outcome |
|-------|-----------|---------|
| Coarse | 75–95 | Audible; needed more headroom |
| Fine (step 5) | 95–110 | **100 selected** — clear cab level within power spec |

Test clip: **`700000001213.wav`** via **`aplay -D driver_speaker`**. Ring sanity: **`/var/lib/vix/recorded-voice-audio/ring.wav`**.

**Forbidden:** **DVC 110 + amp 28** — distortion and ~90 W (Michael bench reference at **92+23**).

**Remote listen:** RustDesk hear tests require **mic bridge** on the USB host XPS (**`use-rustdesk-built-in-mic.sh`**, **`DISABLE_AEC=1`**) — not gadget bridge for routine cab checks.

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
