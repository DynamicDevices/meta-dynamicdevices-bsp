# DT510 — TAS6424 class-D ALSA (“Tannoy”) configuration

**Scope:** **`imx8mm-jaguar-dt510`** only. **BSP:** **`recipes-bsp/alsa-state/alsa-state/imx8mm-jaguar-dt510/`** installs **`/etc/asound.conf`** and **`tas6424-init`** (+ systemd unit).

**Hardware:** TI **TAS6424E‑Q1** via **`sound-tas6424`** (**`tas6424-classd`**). Product wiring uses **IEC stream slots 2 and 3** for the **two Tannoy** outputs; slots **0 and 1** are unused on this 4-slot open but remain on the wire for soak (**`tannoy_all`** only).

**Progress tag (BSP repo):** **`dt510-tier-c2-tannoy-test-1`** — annotated **`meta-dynamicdevices-bsp`** snapshot for this write-up plus related plan/checklist deltas (Tier C2 Tannoy path **working** / **`TAS6422`** **`slot0`/`slot1`** migration note).

---

## Status (engineering)

| Layer | Notes |
|--------|--------|
| **Kernel / DT** | **`tas6424@6a`**, **SAI1**, **`CONFIG_SND_SOC_TAS6424`**, **`I2S_FRAME_SYNC_EXT`** pinctrl fix (Foundries-era **337+** narrative — see Cursor rule **`memory-dt510-foundries-337-338-tas6424-i2s`** or project plan). |
| **Userspace ALSA** | **Working:** **`pcm`/`ctl` `tannoys`**, **`tannoy_slot2`/`slot3`** + schematic aliases **`tannoy_out2`/`out3`**, **`tannoy_both_mono`/`tannoy_both_lr`**, **`tannoy_all`** — lab **`aplay`** validation. **`plug`** wrappers handle typical **rates/formats**; raw **`pcm.tannoys`** is **`hw`** (match params or use **`plug:tannoys`**). |
| **Volume controls** | Patches **`0026`** (rename → **Tannoy CHn**) + **`0027`** (**`SOC_SINGLE`**, linear **0–255**, no dB TLV). |

---

## Naming

| Name | Meaning |
|------|---------|
| **`tannoys`** | Friendly **`pcm`/`ctl`** device — card short id **`tas6424classd`** in **`/proc/asound/cards`**, not the hyphenated **`tas6424-classd`** long label. |
| **`tannoy_slot2` / `tannoy_slot3`** | **One** Tannoy each — map to **IEC indices 2 and 3** (digital slot naming). |
| **`tannoy_out2` / `tannoy_out3`** | Same **`route`** as **`tannoy_slot2`/`slot3`** — schematic **OUT2** / **OUT3** naming for the same two physical feeds. |
| **`ctl.tannoy_out2` / `ctl.tannoy_out3`** | Same **`hw`** mixer card as **`ctl.tannoys`** (**optional** convenience for **`amixer -D tannoy_out2`** …). |
| **`tannoy_both_mono`** | Mono duplicated to **slots 2+3** only. |
| **`tannoy_both_lr`** | Stereo: **L→slot2**, **R→slot3**. **Real 2ch** WAV (or **`aplay -c 2`**) exercises both paths independently. **`vix-apps` / AVM** dual passenger output currently sends **mono** duplicated to identical L+R (same summed loudness as **`tannoy_both_mono`**) via **`audio_player`** until independent L/R content is mixed. **Typical onboard default:** **`passengers_output_device`** targets **`audio_loop`** (TAC5301 cabin loop); use **`tannoy_both_*`** when this class‑D path must carry passenger announcements instead. |
| **`tannoy_all`** | Mono duplicated to **IEC 0–3** (hits unused 0–1 — **lab / soak**, not routine product playback). |

**Passenger tannoy mixer widgets:** **`amixer -D tannoys scontrols`** shows **`Tannoy CH1`–`CH4`** (kernel **`0026`** + **`0027`**) or legacy **`Speaker Driver CH1`–`CH4`** on older images. **alsamixer -D tannoys** bar value = **hardware register** (with **`0027`**). **Driver** volume is **TAS2563** on **`drivers`** — see [`DT510-TAS2563-DRIVER-SPEAKER-ALSA.md`](DT510-TAS2563-DRIVER-SPEAKER-ALSA.md).

---

## Volume (lab dB `sset` with `--`)

| Use | Form | Example |
|-----|------|---------|
| **Lab bench / AVM / boot** | dB via **`sset --`** | **`amixer -D tannoys sset "Speaker Driver CH1" -- -17.5dB`** |
| **`TAS6424_BOOT_VOL`**, **`passenger_tannoy_alsa_db`** / **`passenger_tannoy_alsa_volume`** | dB number | Lab default **`-17.5`** (optional **`dB`** suffix) |
| **Linear 0027 kernel** | Index **0–255** also exists | dB **`sset`** may not apply on **0027** — lab uses dB form for current testing |

**MUST** use **`--`** before negative dB or amixer treats **`-17.5`** as an option and fails.

**Kernel patches (apply in order):**

- **`0026-asoc-tas6424-rename-passenger-tannoy-controls.patch`** — **Tannoy CHn** names.
- **`0027-asoc-tas6424-linear-volume-controls.patch`** — **`SOC_SINGLE`** instead of **`SOC_SINGLE_TLV`**.

**Legacy TLV / index-only images:** **`dt510-tannoy-level-linear.sh`** (percent → register).

Boot **`tas6424-init`** sets each channel via **`sset "${ch}" -- ${VOL_DB}dB`** (default **`-17.5`**). Overrides: **`TAS6424_MIXER`**, **`TAS6424_BOOT_VOL`**, **`TAS6424_VOL_CH1`**–**`CH4`** (control **names**).

---

## Bench hear test (host)

On lab unit (e.g. **`fio@192.168.2.205`**):

```sh
amixer -D tannoys scontrols
for n in 1 2 3 4; do
  amixer -q -D tannoys sset "Speaker Driver CH${n}" -- -17.5dB
done
aplay -D tannoy_both_mono /var/lib/vix/recorded-voice-audio/ring.wav
```

**Helper (dB):** **`vix-apps/AVM/scripts/dt510-tannoy-level.sh set -17.5`** or **`set -17.5dB`**

**Helper (legacy TLV / index):** **`dt510-tannoy-level-linear.sh`**

---

## Quick commands

```sh
aplay -D tannoy_slot2 /path/to.wav
aplay -D tannoy_both_mono /path/to/mono.wav
amixer -D tannoys scontrols
amixer -D tannoys sset "Speaker Driver CH1" -- -17.5dB
```

---

## Future: **TAS6422E‑Q1** (2‑channel successor)

Replacing **TAS6424** with a **2‑channel** part (e.g. **TAS6422**) will **not** be a DTS/`compatible`-only tweak: expect **new/updated codec node**, **driver `CONFIG_*`**, and **`asound.conf` rewrite**.

**IEC slot numbering:** stereo on a **2‑open** PCM typically uses **slots 0 and 1**. Today's BSP intentionally routes the product Tannoys on **slots 2 and 3**. On migration:

1. **`asound.conf`:** redefine routes so the **logical “left/right” PCMs align with `ttable` output indices **`0`** and **`1`**.
2. **`tannoy_both_*`:** update **`ttable`** lines from **`.2`/`.3`** to **`.0`/`.1`**.
3. **`pcm._tas6424_quad`** / **`channels 4`** may become **`channels 2`** depending on DAIFMT / driver.
4. **`tas6424-init`** → successor script / mixer control names.

Track in [**`DT510-BSP-PROJECT-PLAN.md`**](DT510-BSP-PROJECT-PLAN.md) Tier **C2** when the silicon swap is scheduled.

---

*Last updated: 2026-05-20 — linear volume **0027**; lab default index **20**. **Companion (driver amp):** [`DT510-TAS2563-DRIVER-SPEAKER-ALSA.md`](DT510-TAS2563-DRIVER-SPEAKER-ALSA.md).*
