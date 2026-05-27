# DT510 — audio playback investigation (living doc)

**Update this file** as bench/container findings change. Canonical ALSA/codec detail stays in linked docs — not duplicated here.

| Reference | Path |
|-----------|------|
| TAS6424 tannoy ALSA | [`DT510-TAS6424-TANNOY-ALSA.md`](DT510-TAS6424-TANNOY-ALSA.md) |
| RustDesk **mic bridge** (lab default) | [`../../vix-apps/AVM/scripts/RUSTDESK_AUDIO_LAPTOP.md`](../../vix-apps/AVM/scripts/RUSTDESK_AUDIO_LAPTOP.md) — **`use-rustdesk-built-in-mic.sh`**; gadget bridge secondary |
| AVM container debugging | [`../../vix-apps/AVM/VIX_HANDOFF_AVM_DEBUGGING.md`](../../vix-apps/AVM/VIX_HANDOFF_AVM_DEBUGGING.md) |

---

## 1. Purpose / scope

- **Goal:** Reliable **passenger tannoy** (TAS6424) and **container RV/AVM** playback on DT510 lab hardware.
- **Paths under test:**
  - **Host OS:** `aplay` → `tannoy_*` / `tannoy_both_mono` (48 kHz mono).
  - **Containers:** **RecordedVoice** → **AVM** (`rv_connection` :9800 → dataport :9700) → `aplay` → `tannoy_both_mono`.
- **Lab board:** **`fio@192.168.2.205`** (bench move **2026-05-20**; **192.168.2.83** retired). Override with **`BOARD=`** / **`VIX_BOARD_HOST=`**.
- **Out of scope here:** Full RTIG/private spec, Foundries OTA scheduling, USB-gadget-only regression (see handoff + `TESTING_DUAL_AUDIO.md`).

---

## 2. What works (verified)

**Lab default (target images with kernel patches `0026` + `0027`):** set **Tannoy CH1–CH4** (or legacy **Speaker Driver CHn**) to **`-17.5dB`** via **`amixer sset "${ch}" -- -17.5dB`** — **not** linear index **20**, **not** **`20%`**. See [`DT510-TAS6424-TANNOY-ALSA.md`](DT510-TAS6424-TANNOY-ALSA.md).

| Item | Notes |
|------|--------|
| Host **`aplay -D tannoy_both_mono`** | Audible after **CH1–CH4 at `-17.5dB`** (**`sset --`**). |
| **Bench confirmed (2026-05-20)** | **`amixer -D tannoys sset "Speaker Driver CH${n}" -- -17.5dB`** sets level correctly on **`.205`**. |
| **`aplay -D tannoy_both_mono`** + **`ring.wav`** (22050 stereo) | **`/var/lib/vix/recorded-voice-audio/ring.wav`** audible on bench after **`asound.conf`** rate path (**`_tas6424_quad_48`** + **`plug` `slave.rate 48000`** on **`tannoy_both_mono`**). |
| **`dt510-tannoy-level.sh set -17.5`** | Canonical helper; probes **Tannoy CHn** vs **Speaker Driver CHn**. |
| **Legacy TLV only (pre-`0027`)** | **`sset 20%`** → register **~51**; bare **`cset 172`** trap — use **`dt510-tannoy-level-linear.sh`**, not index **20** or **`20%`** as lab default. |
| **RecordedVoice library on board** | Persistent host path **`/var/lib/vix/recorded-voice-audio`** (container **`/audio`**); install via **`install-vix-nsa-audio-on-board.sh`**. |
| **Mic bridge** RustDesk on dev laptop (lab default) | Room tannoy → XPS mic → **`use-rustdesk-built-in-mic.sh`** → RustDesk; not gadget bridge. |
| **`install-vix-nsa-audio-on-board.sh`** | Installs **`recorded_voice_audio`** WAVs + service stems (`ring`, `TR1`, …) to board; **`BOARD=fio@192.168.2.205`**. |
| Container drop-folder (dual-codec config) | **`/tmp/vix-avm-audio/passenger`** + **`config.txt`** → **`tannoy_both_mono`** @ **48 kHz** — driver + passenger audible (**2026-05-18** milestone in handoff). |
| AVM fixes **998f7fe** / **ba76b6b** | Passenger **long-lived `aplay` pipe**; avoids one-shot teardown zeroing TAS6424 levels. |

---

## 3. What fails / symptoms

- **Silent container play** while host **`aplay`** works (mixer at 0, wrong device, empty RV library, or pipe/format mismatch).
- **`alsamixer` at 0** → silent tannoy (boot **`tas6424-init`** not run or overridden).
- **`amixer cset "Speaker Driver CH1 Playback Volume" 20`** (no **`name=`**) — **broken**: simple control stays **0**, **silent**; **`cget`** without **`name=`** also fails.
- **`amixer sset/cset` with `Tannoy CHn`** on **legacy** images (only **Speaker Driver CHn**) — no-op / wrong name.
- **AVM on containers image ~394** (pre-**dd5bf92**): tannoy volume apply still targets legacy **Speaker Driver CHn** → fails or no-op.
- **22.05 kHz stereo** WAV without **`asound.conf`** rate chain → **48 kHz** IEC path: **`aplay` exit 0**, inaudible on TAS6424 (mitigated: **`_tas6424_quad_48`** + **`plug` `slave.rate 48000`** — bench **`ring.wav`** OK **2026-05-20**).
- **PTT held** → **`DRIVER_PA`** tasks flood queue; passenger/RV clips delayed or starved.
- **Raw `$ring;` on TCP 9700** — ignored; dataport expects **JSON** (or XML watchdog), not bare RV tokens.
- **Missing `/etc/asound.conf` `tannoys` alias** on fresh **.205** LmP → container **`passengers_output_device = tannoy_both_mono`** fails open.
- **Missing `tas6424-init.service`** on some images → CH levels stay 0 until manual mixer.

---

## 4. Root causes found

| Issue | Evidence | Fix | Status |
|-------|----------|-----|--------|
| Empty **RecordedVoice** library on board | RV lookup miss; AVM task completes, no file | **`install-vix-nsa-audio-on-board.sh`** + stems | Fixed when install run |
| **22.05 kHz stereo** vs **48 kHz** IEC hw | Host inaudible without rate plugin; `aplay` OK exit | BSP **`asound.conf`**: **`_tas6424_quad_48`** + **`plug` `slave.rate 48000`**; AVM **`audio_sample_rate = 48000`** / pydub | Host **`ring.wav`** OK on bench **2026-05-20** |
| **TLV dB curve vs linear index** | **`alsamixer` bar 20** showed **−17.5 dB**; **`sset 20%`** → cset **51**; index **20** ≠ audible lab level | Lab uses **`sset -- -17.5dB`**; AVM **`passenger_tannoy_alsa_db=-17.5`**; **`tas6424-init`** dB boot | Confirmed bench **2026-05-20** — [`DT510-TAS6424-TANNOY-ALSA.md`](DT510-TAS6424-TANNOY-ALSA.md) |
| **SAI1 @ 44.1 kHz** | **`failed to derive required Tx rate: 2822400`** | Use **48 kHz** tannoy PCMs; avoid raw **`tannoys`** @ **44100** | Usually benign on bench if product path is **48 kHz** |
| **SAI3 / driver @ 44.1 kHz** | Same **2822400** / **EINVAL** on **`&sai3`** (TAS2563) | **`driver_speaker`** / **`driver_slot`** / **`driver_out`** with **`_tas2563_*_48`** + **48 kHz** plug (BSP **`asound.conf`**) | Same fix as tannoy — **2026-05-27** |
| **Tannoy CH** vs **Speaker Driver CH** naming | `amixer -D tannoys scontrols` shows one set | Kernel **0026** + **`cset name='Tannoy CHn Playback Volume' 20`**; **`dt510-tannoy-level.sh`** | Fixed on new BSP + AVM **dd5bf92** |
| **`cset` without `name=`** | alsamixer **0**, **silent**; **`cget`** may mislead | Use **`sset`** or **`cset name='… Playback Volume'`** | Docs + **tas6424-init** + AVM **sset** first |
| Passenger **one-shot `aplay` pipe teardown** zeroing TAS6424 | Silent after first clip; CH readback 0 | **998f7fe** — avoid teardown side effect | Fixed (vix-apps) |
| Keep passenger pipe open between clips | Second clip silent / quiet | **ba76b6b** — **`ensure_passenger_aplay_pipe()`**, streaming path | Fixed (vix-apps) |
| AVM **Speaker Driver CHn** on image **394** | `amixer` errors in container logs | **dd5bf92** + containers OTA | Needs OTA on bench |
| **missing `tas6424-init`** | Boot CH=0 until manual | BSP **`alsa-state`** + systemd unit | Image-dependent |
| **missing `asound.conf` / `tannoys`** on **.205** | `aplay -D tannoy_both_mono` unknown | LmP with BSP **alsa-state**; bind-mount in compose | Verify per flash |
| **PTT stuck** flooding queue | Continuous **`DRIVER_PA`** in `docker logs avm` | Release PTT; fix GPIO polarity (**containers ≥393**, BSP DTS) | Intermittent lab |
| **JSON AnnounceRequest** vs raw **`$ring`** on **9700** | Bare string not parsed | NDTR-shaped **`{"type":"RV","sub_type":"AnnounceRequest",…}`** or RV XML on **9800** | Documented |

---

## 5. Correct procedures

### Pre-flight (host, before any play)

```sh
ssh fio@192.168.2.205
amixer -D tannoys scontrols   # expect Tannoy CH1-4 (or legacy Speaker Driver CHn on old kernel)
# Probe: amixer -D tannoys scontrols
for n in 1 2 3 4; do
  amixer -q -D tannoys sset "Speaker Driver CH${n}" -- -17.5dB
done
# or: vix-apps/AVM/scripts/dt510-tannoy-level.sh set -17.5
# legacy TLV only: dt510-tannoy-level-linear.sh
# legacy names: Speaker Driver CHn until 0026+0027 image — probe in script/tas6424-init
```

### Host tannoy test

Set levels (**alsamixer** or **`cset`**), then play (RV stem or any WAV — **`asound.conf`** resamples to 48 kHz on **`tannoy_*`** PCMs):

```sh
# Probe: amixer -D tannoys scontrols (Tannoy CHn or Speaker Driver CHn)
for n in 1 2 3 4; do
  amixer -q -D tannoys sset "Speaker Driver CH${n}" -- -17.5dB
done
aplay -D tannoy_both_mono /var/lib/vix/recorded-voice-audio/ring.wav
# bench 2026-05-20: 22050 Hz stereo, audible
aplay -D tannoy_both_mono -r 48000 -c 1 /path/to/mono48k.wav
```

**`asound.conf` (imx8mm-jaguar-dt510):** **`pcm._tas6424_quad_48`** (`type rate` → **48000** on **`_tas6424_quad`**) and each **`tannoy_*`** product PCM uses **`type plug`** with **`slave.rate 48000`** routing into **`_tas6424_quad_48`** (file: **`recipes-bsp/alsa-state/alsa-state/imx8mm-jaguar-dt510/asound.conf`**). SHAs **`878b56e5`** / **`8fcb6fd3`** are not in local BSP **`git log`** yet — pin here when pushed.

### Container play

- **Drop-folder (fastest):** copy WAV + **`config.txt`** into **`/tmp/vix-avm-audio/passenger`** (see handoff); ensure **`passengers_output_device = tannoy_both_mono`**, **`audio_sample_rate = 48000`**.
- **RV → AVM path:** NDTR/service sends **JSON** to **AVM :9700** — not raw **`$ring;`** on 9700. For manual inject from host:

```sh
CN=$(docker ps --format '{{.Names}}' | grep -E 'avm' | grep -v ndtr | head -1)
# Example shape only — fill text/id from NDTR messages.py / bench capture:
docker exec "$CN" python3 -c "
import json, socket
s = socket.create_connection(('127.0.0.1', 9700))
s.sendall(json.dumps({'type':'RV','sub_type':'AnnounceRequest','text':'\$ring;','priority':'high','id':1}).encode())
s.close()
"
```

- **RecordedVoice library install (dev machine):**

```sh
cd vix-apps/RecordedVoice/scripts
BOARD=fio@192.168.2.205 ./install-vix-nsa-audio-on-board.sh "/path/to/audio files.zip"
```

---

## 6. Bench checklist (copy-paste)

```text
[ ] Board SSH: fio@192.168.2.205 (not .83)
[ ] aplay -l shows tas6424classd card
[ ] test -f /etc/asound.conf && grep -q tannoys /etc/asound.conf
[ ] systemctl is-active tas6424-init.service (or manual CH1-4 sset -- -17.5dB)
[ ] amixer -D tannoys sget 'Speaker Driver CH1' (or Tannoy CH1) → ~-17.5 dB after sset -- (not silent at 0)
[ ] Host: aplay -D tannoy_both_mono /var/lib/vix/recorded-voice-audio/ring.wav → audible (22050 stereo OK with rate plugin)
[ ] Host: aplay -D tannoy_both_mono -r 48000 -c 1 <mono.wav> → audible in room
[ ] docker ps: avm + recordedvoice running
[ ] RV audio dir populated (install-vix-nsa-audio-on-board.sh)
[ ] docker logs avm: no stuck PTT / DRIVER_PA flood
[ ] Container: drop-folder OR JSON AnnounceRequest on 9700 → passenger audible
[ ] Optional: RustDesk acoustic test per RUSTDESK_AUDIO_LAPTOP.md
```

---

## 7. SAI1 `fsl-sai` / 44.1 kHz probe (dmesg)

**Symptom (some boots / images):**

```text
fsl-sai 30010000.sai: failed to derive required Tx rate: 2822400
fsl-sai 30010000.sai: ASoC: error at snd_soc_dai_hw_params on 30010000.sai: -22
```

| Item | Detail |
|------|--------|
| **SAI** | **`30010000.sai`** = **`&sai1`** in **`imx8mm-jaguar-dt510.dts`** → **TAS6424** tannoy path |
| **2822400** | **44100 × 64** — typical **BCLK** for **44.1 kHz** IEC/TDM open |
| **Clock** | **SAI1** uses **`AUDIO_PLL1_OUT` @ 12.288 MHz** (48 kHz family) — **fsl-sai** often **cannot** derive **44.1 kHz** BCLK → **`-EINVAL` (-22)** |
| **Product rate** | **`asound.conf`** forces **48 kHz** on **`tannoy_*`** (`_tas6424_quad_48` + **`plug` `slave.rate 48000`**); **AVM** **`audio_sample_rate = 48000`**; **`ring.wav`** is **22050** but resampled in that chain |
| **Harmless?** | **Usually yes** if playback uses **`tannoy_both_mono`** / **`tannoy_both_lr`**, not raw **`pcm.tannoys`** at **44100**. Bench **`.205`**: **`aplay -D tannoy_both_mono`** + **`ring.wav`** OK; **`aplay -D tannoys -r 44100`** fails userspace (hw params), may or may not log kernel line on current boot |
| **Breaks tannoy?** | **No** when rate plugin path is used; **yes** if something opens **`tannoys`** hw at **44100** (codec advertises **44100–96000**) without resampling |
| **BSP fix (if chasing log noise)** | Ensure all init/play uses **48 kHz** PCMs; optional driver/DT work to drop **44.1** from hw constraint list — only if a product path truly needs **44.1** on **SAI1** |

**SAI3 (driver speaker):** **`30030000.sai`** = **`&sai3`** → **TAS2563**. Same **12.288 MHz** / **2822400** failure if **`drivers`** opens at **44100**. Product path **`driver_speaker`** (and **`driver_slot`** / **`driver_out`**) now use **`_tas2563_48`** / **`_tas2563_tdm_48`** like **`_tas6424_quad_48`** — see **`docs/DT510-TAS2563-DRIVER-SPEAKER-ALSA.md`**.

---

## 8. Open questions / next steps

- [ ] **.205** factory image: confirm **LmP pin** includes **cf260b8** + **alsa-state** (`tannoys`, **`tas6424-init`**).
- [ ] **Containers OTA** past **394** with **dd5bf92**, **998f7fe**, **ba76b6b** on bench — retest RV **`$ring`** end-to-end without hotpatch.
- [ ] **PTT / DI polarity** retest after **LmP + containers** OTA (active-high DTS vs **`dt510_gpio.py`**).
- [ ] **`audio_loop` vs `tannoy_both_mono`** product default for passenger PA in fleet config.
- [ ] Soak: repeated **`$ring`** / stop clips — CH levels stay at **-17.5dB** after many plays (regression for **998f7fe**).
- [ ] Document canonical **JSON** template for **9700** in a small bench script (avoid raw **`$ring`** confusion).

---

## 9. Git SHAs (reference)

| SHA | Repo | Summary |
|-----|------|---------|
| **cf260b8** | meta-dynamicdevices-bsp | Kernel/userspace narrative: rename TAS6424 controls → **Tannoy CH1–4** |
| **0026** (patch) | meta-dynamicdevices-bsp | `asoc-tas6424-rename-passenger-tannoy-controls` |
| **0027** (patch) | meta-dynamicdevices-bsp | `asoc-tas6424-linear-volume-controls` (**SOC_SINGLE**, no TLV) |
| **6ecbb58** | meta-dynamicdevices-bsp | Docs: Speaker Driver CHn = passenger tannoys only |
| **ba76b6b** | vix-apps | Keep passenger **aplay** pipe open on DT510 tannoy |
| **998f7fe** | vix-apps | Prevent tannoy PCM teardown zeroing TAS6424 mixer |
| **dd5bf92** | vix-apps | AVM uses **Tannoy CH1–4** ALSA names + **cset** |
| **8c2764b** | vix-apps | RV: remove **audio-lab-stems** symlink (Foundries compose) |

---

## Changelog

| Date | Notes |
|------|--------|
| **2026-05-19** | Bench **.83**: host `aplay` OK after CH=20; container silent — traced mixer **cset**, legacy control names, pipe teardown (**998f7fe** / **ba76b6b**); PTT queue flood observed. |
| **2026-05-20** | Bench moved to **fio@192.168.2.205**; living doc created; links to TAS6424 / RustDesk / AVM handoff. |
| **2026-05-20** | **.205**: `/etc/asound.conf` was an empty **directory** (not BSP file) — Docker bind-mount created host dir when file missing before first `avm` start (`/etc/asound.conf:/etc/asound.conf:ro`). Fixed: stop `avm`, `rm -rf`, install BSP `asound.conf`, `docker compose up -d avm`. |
| **2026-05-20** | Bench **`.205`**: TLV/index traps documented; lab standard **`sset -- -17.5dB`** confirmed audible. AVM/tas6424-init use dB; **`ring.wav`** OK with **`_tas6424_quad_48`**. RustDesk lab default = **mic bridge** (`use-rustdesk-built-in-mic.sh`). |
