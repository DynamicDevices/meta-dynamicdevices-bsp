# DT510 — Auracast / LE Audio (IW612) implementation tracker

**Purpose:** One place to record **what is implemented**, **what is verified on hardware**, and **what remains** for Bluetooth **LE Audio** and **Auracast-style BAP broadcast** on **i.MX8MM Jaguar DT510** (IW612 / `nxpiw612-sdio`). Update this file when the stack, image, or lab results change.

**Maintaining this doc (do every time Auracast / LE Audio work lands or lab status changes):**

1. Edit **What’s done** and **What still needs doing** so they stay accurate one-screen summaries.
2. Tick / add rows in **Checklist — continue over time** (mirror of the summaries).
3. Add a **Lab log** row: date, how you reached the board (e.g. SSH target), what was proven (or failed).
4. Add a **Changelog** row: date + one short sentence.
5. Do **not** commit **NXP confidential** PDF excerpts — cite **UM12155** + section only.
6. On-target proof: use **filesystem paths** only (see [Filesystem evidence](#filesystem-evidence-on-target-no-rpmopkg)); do **not** depend on **`rpm`** / **`opkg`** on the board.

**External SSOT (do not paste NXP confidential text into git):** NXP **UM12155** (*Bluetooth LE Audio* user manual) and NXP **LEA-patched** Yocto / BlueZ guidance (e.g. **UG10164**, **LEA Patches** user guide). Keep PDFs and NXP-only drops **out of the public repo** unless distribution is cleared.

**Related:** [`DT510-HARDWARE-AUDIT-CHECKLIST.md`](DT510-HARDWARE-AUDIT-CHECKLIST.md) · [`meta-subscriber-overrides/conf/DT510-HARDWARE-BRINGUP.md`](../../meta-subscriber-overrides/conf/DT510-HARDWARE-BRINGUP.md)

---

## What’s done (summary)

**Build / image (Yocto — in tree)**

- **`auracast`** is enabled on **`imx8mm-jaguar-dt510`** together with **`nxpiw612-sdio`** (IW612 prerequisite).
- **`lmp-factory-image.bb`** pulls **`lmp-feature-le-audio.inc`** when **`auracast`** is set → rootfs gets **PipeWire**, **WirePlumber**, **bluez5**, **`le-audio-wireplumber-config`**. **`bluez5-testtools`** (**`btmgmt`**) is appended only from **`lmp-feature-iw612.inc`** on IW612 machines when dev builds are enabled (see Yocto table below).
- **PipeWire** target build adds **alsa**, **pipewire-alsa**, **bluez**, **bluez-opus**, **bluez-lc3** via **`pipewire_%.bbappend`** (so LC3/BAP backend is not lost on headless distros).
- **WirePlumber** installs **`51-bluez-imx-le-audio.conf`** (BAP unicast + **`bap_bcast_source` / `bap_bcast_sink`** + LC3 in codec list).
- **LmP static IDs** for **`pipewire`** user via **`lmp-useradd-pipewire.inc`** (distro `*.conf` includes it).
- **On-target helper script** in BSP: **`dt510-auracast-image-check.sh`** — verifies the stack by **filesystem paths only** (no **`rpm`** / **`opkg`** on target). Installed via **`board-scripts_1.0.bb`** on **`imx8mm-jaguar-dt510`** when that recipe revision is in the built image.

**Docs / cross-links**

- This tracker exists; **audit checklist** and **`DT510-HARDWARE-BRINGUP.md`** link here.

**Lab (partial — not “LE Audio works end-to-end”)**

- **Rootfs inventory (lab):** see [Filesystem evidence](#filesystem-evidence-on-target-no-rpmopkg) — **PASS** on **`fio@192.168.2.239`** **2026-05-07** (required paths + **`libspa-codec-bluez5-lc3.so`**). **`/usr/sbin/dt510-auracast-image-check.sh`** not on that flash yet.
- Kernel **6.6.52-lmp-standard**. No CIS/BAP broadcast audio path validated yet.

---

## What still needs doing (summary)

1. **Rootfs proof on shipping images** — same path table as [Filesystem evidence](#filesystem-evidence-on-target-no-rpmopkg); run **`/usr/sbin/dt510-auracast-image-check.sh`** once the BSP revision that installs it is on the flash (**lab 192.168.2.239** already validated via inline checks **2026-05-07**).
2. **NXP LEA-capable BlueZ** — align **`bluez5`** with NXP **LEA-patched** build / IW612 release notes (today: stock OE **`bluez5`** unless another layer overrides).
3. **Boot / session policy** — define who runs **PipeWire + WirePlumber** at boot (**`systemd --user`** + **linger** vs system services); **`bluetoothd`** flags per NXP bring-up if needed.
4. **Pulse vs PipeWire** — if both ship, pick default Bluetooth audio path and document it.
5. **UM12155-style hardware flows** — run **CIS** then **BAP broadcast** on DT510; map **`wpctl` / `pw-play` / `pw-link`** to **this board’s** ALSA nodes (not EVK WM8524 names).
6. **Config hardening** — validate **`bluez5.hfphsp-backend`** (`native` vs **`ofono`**) after BlueZ source is fixed; trim **`bap_bcast_*`** roles if WirePlumber rejects tokens for a given version pair.
7. **Ship tracker + script** — ensure **`meta-dynamicdevices-bsp`** revision on the factory line includes this doc and **`dt510-auracast-image-check.sh`** (commit/push + manifest pin as per your release process).

**Lab SSH:** DT510 units used for checks include **`192.168.2.239`** and **`192.168.2.88`** ( **`192.168.2.139`** was unreachable from the automation host).

---

## Filesystem evidence on target (no rpm/opkg)

**Rootfs inventory** — prove the **LE Audio / Auracast host stack** (PipeWire + WirePlumber + BlueZ + LC3 SPA) is on the image by **paths on disk only**. Do **not** use **`rpm`**, **`opkg`**, or **`dpkg`** on the DT510 for this; package databases may be absent or unreliable on headless images.

### Policy

- **Pass** = every **Required** path below exists (executable or regular file as noted).
- **Investigate** if a **Required** path is missing — build recipe split, `FILES`, or image variant changed.
- **Optional** rows document what we expect when **`bluez-lc3`** / BlueZ5 SPA is enabled; layout can differ by Yocto version — update this section and **`dt510-auracast-image-check.sh`** together.

### Required paths (inventory must pass)

| # | Role | Path | Notes |
|---|------|------|--------|
| 1 | PipeWire daemon CLI | `/usr/bin/pipewire` | executable |
| 2 | WirePlumber | `/usr/bin/wireplumber` | executable |
| 3 | BlueZ CLI | `/usr/bin/bluetoothctl` | executable |
| 4 | BlueZ daemon | `/usr/libexec/bluetooth/bluetoothd` **or** `/usr/lib/bluetooth/bluetoothd` | at least one executable (**lab:** **`/usr/libexec/...`** present) |
| 5 | LE Audio WirePlumber drop-in | `/usr/share/wireplumber/wireplumber.conf.d/51-bluez-imx-le-audio.conf` | from **`le-audio-wireplumber-config`** |

### SPA / codec plugins (LC3 — expect on `auracast` images)

| # | Role | Path | Notes |
|---|------|------|--------|
| 6 | PipeWire BlueZ5 SPA directory | `/usr/lib/spa-0.2/bluez5/` **or** `/usr/lib64/spa-0.2/bluez5/` | directory with **`*.so`** plugins |
| 7 | LC3 codec plugin (Auracast / LE Audio) | `…/bluez5/libspa-codec-bluez5-lc3.so` | under the directory from row 6 (**lab:** present) |
| 8 | BlueZ5 SPA core | `…/bluez5/libspa-bluez5.so` | (**lab:** present) |

**Lab observation (2026-05-07, `192.168.2.239`):** under **`/usr/lib/spa-0.2/bluez5/`** the image also had **`libspa-codec-bluez5-{aac,faststream,opus,sbc}.so`** — useful sanity check, not individually required for “minimal LE Audio” inventory.

### Packaged check script (optional path)

| # | Role | Path | Notes |
|---|------|------|--------|
| 9 | BSP smoke script | `/usr/sbin/dt510-auracast-image-check.sh` | installed when **`board-scripts`** recipe revision on the image includes it — **not** on the **2026-05-07** lab flash; use inline checks until OTA catches up |

### Run from dev laptop (inline inventory)

**Lab `sudo`:** Factory **`fio`** images use login password **`fio`** for **`sudo`** when a TTY prompts for it. For **non-interactive** SSH one-liners (no prompt), prefix privileged commands with **`echo fio | sudo -S`** (same caveat as bring-up docs: lab-only).

```bash
ssh fio@192.168.2.239 '
test -x /usr/bin/pipewire && test -x /usr/bin/wireplumber && test -x /usr/bin/bluetoothctl || exit 1
test -x /usr/libexec/bluetooth/bluetoothd || test -x /usr/lib/bluetooth/bluetoothd || exit 1
test -f /usr/share/wireplumber/wireplumber.conf.d/51-bluez-imx-le-audio.conf || exit 1
test -f /usr/lib/spa-0.2/bluez5/libspa-codec-bluez5-lc3.so || test -f /usr/lib64/spa-0.2/bluez5/libspa-codec-bluez5-lc3.so || exit 1
echo rootfs LE Audio inventory: PASS
'
```

When **`dt510-auracast-image-check.sh`** is on the image:

```bash
ssh fio@192.168.2.239 /usr/sbin/dt510-auracast-image-check.sh
```

---

## HCI (`hcitool`) — CIS / BIS opcodes (Linux)

NXP **UM12155** §3 documents the Linux form:

`hcitool -i hci0 cmd <OGF> <OCF> <other_parameters…>`

The **OGF/OCF pairs** in UM12155 Table 3 are the standard **Bluetooth Core Specification** HCI LE / Link commands used for **Connected Isochronous Stream (CIS)** and **Broadcast Isochronous Stream (BIS)** setup (PHY, host features, CIG/CIS, ISO data path, extended advertising, etc.). **Do not paste UM12155 text or tables into git** — cite **UM12155** + section for parameter packing.

**Quick opcode map (verify parameter lengths in Core Spec / UM12155 before sending):**

| HCI command (Core Spec name) | OGF | OCF |
|------------------------------|-----|-----|
| Read BD_ADDR | `0x04` | `0x09` |
| Write Connection Accept Timeout | `0x03` | `0x16` |
| LE Write Suggested Default Data Length | `0x08` | `0x24` |
| LE Set Default PHY | `0x08` | `0x31` |
| LE Set Extended Advertising Parameters | `0x08` | `0x36` |
| LE Enable Encryption | `0x08` | `0x19` |
| LE Set Host Feature (e.g. isochronous channels) | `0x08` | `0x74` |
| LE Set CIG Parameters | `0x08` | `0x62` |
| LE Remove CIG | `0x08` | `0x65` |
| LE Create CIS | `0x08` | `0x64` |
| LE Accept CIS Request | `0x08` | `0x66` |
| LE Setup ISO Data Path | `0x08` | `0x6E` |

**Lab invocation:** non-interactive sudo on factory **`fio`** images: **`echo fio | sudo -S hcitool -i hci0 cmd …`** (see bring-up doc).

**Stack interaction:** **`hcitool cmd`** can succeed for simple queries while **`bluetoothd`** is running (e.g. **Read BD_ADDR**). **LE scan**, **ISO**, and **CIG/CIS** sequences often need correct connection/advertising state and may **conflict** with BlueZ’s ownership of the adapter — expect bring-up scripts to coordinate with **`bluetoothd`** (or use **NXP / BlueZ BAP** paths) rather than raw HCI alone for product Auracast.

**On-target spot-check (DT510, lab):** **Read BD_ADDR** (`0x04` `0x09`) → Command Complete **success**, BD_ADDR matches **`hciconfig`**. **LE Read Buffer Size V2** (`0x08` `0x77`, ISO-related buffers per Core Spec) → **Command Status** status **`0x11`** (*Unsupported Feature or Parameter Value*) on one **`6.6.52-lmp-standard`** IW612 build — treat as **FW/controller capability signal**, confirm against **IW612 + HCI** release notes if UM12155 flow requires it.

---

## Scope

| In scope | Out of scope (for this note) |
|----------|------------------------------|
| Host stack: **BlueZ**, **PipeWire**, **WirePlumber**, **LC3** / BAP roles | Android / FreeRTOS paths in UM12155 |
| **IW612** HCI + SDIO firmware story already on DT510 | Wi‑Fi RF certification |
| **BAP broadcast** (Auracast-style) bring-up and product policy | Copying UM12155 procedures verbatim |

---

## Yocto / BSP — implemented today

| Item | Location |
|------|----------|
| Machine feature **`auracast`** (+ **`nxpiw612-sdio`**) | `meta-dynamicdevices-bsp/conf/machine/imx8mm-jaguar-dt510.conf` |
| Image pulls LE Audio package set when `auracast` set | `meta-dynamicdevices-distro/recipes-samples/images/lmp-factory-image.bb` → `lmp-feature-le-audio.inc` |
| Packages: `pipewire`, `pipewire-alsa`, `wireplumber`, `bluez5`, `le-audio-wireplumber-config` | `meta-dynamicdevices-distro/recipes-samples/images/lmp-feature-le-audio.inc` |
| **`bluez5-testtools`** (**`btmgmt`**, etc.) — dev images only | `meta-dynamicdevices-distro/recipes-samples/images/lmp-feature-iw612.inc` when **`nxpiw612-sdio`** and (**`IMAGE_FEATURES` `debug-tweaks`** / Factory **`DEV_MODE=1`**, or **`LOCAL_DEVELOPMENT_BUILD=1`**) |
| PipeWire **PACKAGECONFIG**: `alsa`, `pipewire-alsa`, `bluez`, `bluez-opus`, `bluez-lc3` | `meta-dynamicdevices-distro/recipes-multimedia/pipewire/pipewire_%.bbappend` |
| WirePlumber drop-in (**BAP + broadcast roles**, LC3 in codec list) | `meta-dynamicdevices-distro/recipes-connectivity/le-audio-wireplumber/le-audio-wireplumber-config/51-bluez-imx-le-audio.conf` |
| Static **pipewire** user IDs (LmP) | `meta-dynamicdevices-distro/conf/distro/include/lmp-useradd-pipewire.inc` (included from distro `*.conf`) |
| On-target smoke script (after BSP ships it) | `meta-dynamicdevices-bsp/recipes-bsp/board-scripts/board-scripts/dt510-auracast-image-check.sh` |

**Known gap vs NXP UM12155 lab flow:** no **`bluez5`** bbappend in this workspace swapping in **NXP LEA-patched** BlueZ — stock **`bluez5`** from the manifest pin is used unless another layer overrides it.

**WirePlumber sample delta:** UM12155 examples sometimes use **`bluez5.hfphsp-backend = "ofono"`**; our drop-in uses **`"native"`** — confirm against NXP LEA stack when BlueZ source is aligned.

---

## Device tree / kernel (IW612)

No separate **“auracast”** DT node: LE Audio rides on existing **UART HCI** + **SDIO** + **`mlan`/`moal`** + firmware paths already described for DT510 bring-up.

---

## Lab log (update when you run checks)

| Date | Board / access | Result |
|------|------------------|--------|
| 2026-05-07 | SSH `fio@192.168.2.239` | **`51-bluez-imx-le-audio.conf`** present; **`pipewire` 1.0.9**, **`wireplumber` 0.5.1**, **`bluetoothctl` 5.72** on **`6.6.52-lmp-standard`** (binary/config presence only). |
| 2026-05-07 | SSH laptop → **`fio@192.168.2.239`** | **Filesystem check exit 0:** **`bluetoothd`**, WirePlumber fragment, **`/usr/lib/spa-0.2/bluez5/`** incl. **`libspa-codec-bluez5-lc3.so`**. **`/usr/sbin/dt510-auracast-image-check.sh`** missing on image (expected until BSP ships that `board-scripts` revision). |
| 2026-05-07 | SSH **`fio@192.168.2.88`** (password auth; host **`imx8mm-jaguar-dt510-2d0c7209dabc234a`**) | **Bluetooth stack inventory (not CIS/BAP runtime):** **`6.6.52-lmp-standard`**; **`hci0`** UART **UP RUNNING**, HCI/LMP **5.4**, manufacturer **NXP (37)**; **`bluetoothd`/`bluetoothctl` 5.72**, **`bluetooth.service` active**, **`/usr/libexec/bluetooth/bluetoothd`**; **`bluetoothctl show`** — roles central+peripheral, extended adv **1M/2M/Coded**; **PipeWire 1.0.9**, **WirePlumber 0.5.1**, **`51-bluez-imx-le-audio.conf`**, **`libspa-codec-bluez5-lc3.so`** present. **`btmgmt`** absent on this **non–dev-mode** flash — **`bluez5-testtools`** now gated to **IW612 + dev** builds (see Yocto table). |
| 2026-05-06 | SSH **`fio@192.168.2.166`** | **Rootfs LE Audio inventory PASS**; privileged **`hcitool cmd 0x04 0x09`** (Read BD_ADDR) **Command Complete success**. **`hcitool cmd 0x08 0x77`** (LE Read Buffer Size V2) → **Command Status** **`0x11`**. Not a full CIS/BIS sequence. |

---

## Checklist — continue over time

*(Mirror of **What’s done** / **What still needs doing** above — tick boxes as work completes.)*

### Done

- [x] **`MACHINE_FEATURES`** includes **`auracast`** on **`imx8mm-jaguar-dt510`**
- [x] **`lmp-feature-le-audio.inc`** wired from **`lmp-factory-image.bb`**
- [x] PipeWire built with **BlueZ + LC3** when **`auracast`**
- [x] **`le-audio-wireplumber-config`** installs BAP / **bcast** role drop-in
- [x] Tracker doc + links (audit checklist, bring-up doc)
- [x] **`dt510-auracast-image-check.sh`** in BSP `board-scripts` (+ `board-scripts_1.0.bb` for **`imx8mm-jaguar-dt510`**) — **filesystem-only** checks (no **`rpm`/`opkg`**)
- [x] Basic **on-target** presence of binaries + drop-in (lab **192.168.2.239**)
- [x] **Rootfs inventory** doc: [Filesystem evidence](#filesystem-evidence-on-target-no-rpmopkg) (policy, required table, lab SSH snippets) + maintenance rule

### Next (priority order)

- [x] **Rootfs inventory (lab):** SSH from dev laptop → **`192.168.2.239`** — all paths in [Filesystem evidence](#filesystem-evidence-on-target-no-rpmopkg) present; LC3 BlueZ5 SPA plugin on disk (**`libspa-codec-bluez5-lc3.so`**).
- [ ] **Rootfs inventory (shipping):** after BSP/manifest ships **`dt510-auracast-image-check.sh`**, confirm **`/usr/sbin/dt510-auracast-image-check.sh`** on image and run it; extend path table + script if layout changes.
- [ ] **NXP LEA BlueZ:** decide recipe source (NXP patch set vs OE); add **`bluez5`** bbappend or layer pin per NXP + IW612 release notes.
- [ ] **Runtime:** boot policy for **`pipewire`/`wireplumber`** (user session + **linger** vs system units); **`bluetoothd`** args if NXP requires **`-E`** / debug for bring-up only.
- [ ] **Coexistence:** PulseAudio vs PipeWire default for Bluetooth audio on DT510 (if both ship).
- [ ] **UM12155 §5 flows on DT510:** CIS unicast then **BAP broadcast**; replace EVK **`wpctl`** node names with **DT510** sinks/sources (e.g. product codecs).
- [ ] **Trim roles if needed:** if WirePlumber rejects **`bap_bcast_*`** tokens for a given BlueZ/WirePlumber pair, narrow `51-bluez-imx-le-audio.conf` per drop-in comment.
- [ ] **Release process:** commit/push BSP and pin manifest so factory images pick up this doc + **`dt510-auracast-image-check.sh`**.

---

## Changelog

| Date | Change |
|------|--------|
| 2026-05-07 | Initial tracker; lab **192.168.2.239**; links; executive **done / remaining** + checklist sync. |
| 2026-05-07 | **Maintaining this doc** instructions; Cursor rule **`memory-dt510-auracast-le-audio-tracker.mdc`** to prompt updates when touching LE Audio / Auracast files. |
| 2026-05-07 | Verification policy: **filesystem paths only** on target (no rpm/opkg); **`dt510-auracast-image-check.sh`** + doc table updated. |
| 2026-05-07 | SSH from laptop to **192.168.2.239**: inline filesystem check **pass**; packaged **`dt510-auracast-image-check.sh`** not on flash yet. |
| 2026-05-07 | **Rootfs inventory** section expanded: required vs SPA vs packaged script; laptop **`ssh`** one-liner. |
| 2026-05-07 | Lab log: **`fio@192.168.2.88`** — Bluetooth / LE Audio host stack inventory (**`btmgmt`** absent). |
| 2026-05-07 | **`bluez5-testtools`**: moved from always-on LE Audio inc to **`lmp-feature-iw612.inc`**, only when **`nxpiw612-sdio`** + (**`debug-tweaks`/`DEV_MODE`** or **`LOCAL_DEVELOPMENT_BUILD=1`**). |
| 2026-05-06 | **HCI (`hcitool`)** §: UM12155-aligned **OGF/OCF** map for CIS/BIS; lab **`hcitool cmd`** notes + **Read BD_ADDR** / **LE Read Buffer Size V2** spot-check on **`192.168.2.166`**. |
