# DT510 BSP & hardware bring-up — project plan

Working document for aligning **Ollie Hull’s DT510 pinout / hardware specification** with **`meta-dynamicdevices-bsp`** (device tree, kernel fragments, and related recipes). Update this file as the spec evolves and as tasks complete.

---

## 1. Purpose

- Make the **i.MX 8M Mini Jaguar DT510** (`imx8mm-jaguar-dt510`) match the **approved hardware definition** in software (DT, drivers, tests).
- Apply changes in **safe phases** so we do not destabilise **boot**, **OTA**, or **already-working** subsystems (e.g. Wi‑Fi, USB gadget audio, cellular) without intent.

---

## 2. Source of truth (hardware)

| Document | Role |
|----------|------|
| **[VIX DT510 pinout / hardware spec](https://docs.google.com/document/d/1dlVcfW7SrOifR-rGjkJnVbnQBO4uU8HeS1MEfDmgcYE/edit?usp=sharing)** (Google Doc) | **Primary SSOT** for pinmux, buses, I2C addresses, and major components. |

**Rule:** Electrical / mechanical reality wins. The Google Doc is the **first-cut SSOT**; if we find errors on schematic or bring-up, **update the doc** (or an errata section here) and then change the BSP.

---

## 3. Repositories & where things live

| Repo | Role |
|------|------|
| **`DynamicDevices/meta-dynamicdevices-bsp`** (this repo) | Board DTS, kernel `*.cfg` fragments, `linux-lmp-fslc-imx_%.bbappend`, `lmp-device-tree.bbappend`, machine `imx8mm-jaguar-dt510.conf`, userspace recipes tied to the board. **This document lives here.** |
| **`vixdt` / Foundries factory** | Factory images, containers, `vix-apps`; coordinates with BSP for OTA and apps. |

### Foundries: how DT510 images get built and tested

The LmP manifest pulls **`meta-dynamicdevices-bsp`** (e.g. `main` from GitHub) into the factory build. **To trigger a Foundries build** for the DT510 factory line, the team **commits and pushes** to **`meta-subscriber-overrides`** on the active factory branch (e.g. **`main-imx8mm-jaguar-dt510`**) — remote **`source.foundries.io/factories/vixdt/meta-subscriber-overrides`**.

Typical layout: that repo lives beside other factory checkouts (e.g. under a **`vixdt`** workspace as `meta-subscriber-overrides/`). A small commit there (even a doc or comment bump) starts the pipeline that **repo syncs** layers and builds **`imx8mm-jaguar-dt510`**.

**Ordering:** Merge BSP changes to **`DynamicDevices/meta-dynamicdevices-bsp`** `main` first, **then** push **`meta-subscriber-overrides`** so the factory build picks up the new BSP revision (manifest tracks BSP `main` unless pinned otherwise).

**Key paths inside this BSP layer (relative to repo root):**

- Canonical DT for Factory/LmP flows: `recipes-bsp/device-tree/lmp-device-tree/imx8mm-jaguar-dt510.dts`
- Kernel recipe: `recipes-kernel/linux/linux-lmp-fslc-imx/imx8mm-jaguar-dt510.dts` → **symlink** to the canonical file (Tier A1).

**Single-DTS policy:** One file on disk; the kernel recipe path must remain a symlink to the `lmp-device-tree` copy (see §6).

**Reference (not built):** Tool-generated / review-only DTS snapshots from hardware (e.g. Ollie’s generator output) live under **`docs/reference/dt510-ollie-tool-generated/`**. Use them for **requirements review and diffs** only — not as the shipping device tree until merged deliberately into the recipes above.

**Hardware audit (SSOT ↔ BSP):** Living checklist — [`docs/DT510-HARDWARE-AUDIT-CHECKLIST.md`](DT510-HARDWARE-AUDIT-CHECKLIST.md).

---

## 4. Guiding principles

1. **SSOT:** Pinout / BOM decisions follow the Google Doc unless superseded by a documented schematic change.
2. **One change vector per step:** Prefer small PRs/commits that can be reverted and bisected.
3. **Boot first:** Avoid large simultaneous changes to pinctrl, clock parents, and built-in kernel options.
4. **Prefer `=m`:** For new drivers, prefer modules until the integration is proven, where the kernel policy allows.
5. **DT before `CONFIG`:** Add or adjust nodes with correct `compatible` and `reg`; then enable **`CONFIG_*`** via existing fragment layout under `recipes-kernel/linux/linux-lmp-fslc-imx/imx8mm-jaguar-dt510/`.

---

## 5. Phased work plan (priority × risk)

Work **in order** within each tier unless a dependency forces otherwise.

### Tier A — Do first (high value, low boot risk)

| ID | Task | Notes |
|----|------|--------|
| A1 | **Single DTS source** | **Done:** `linux-lmp-fslc-imx/imx8mm-jaguar-dt510.dts` → symlink to `lmp-device-tree/imx8mm-jaguar-dt510.dts` (canonical). |
| A2 | **SSOT header in DTS** | **Done:** Comment block after NXP copyright in canonical DTS (SSOT pointer, symlink note, plan + reference folder). |
| A3 | **Audit spreadsheet / checklist** | **Done:** [`docs/DT510-HARDWARE-AUDIT-CHECKLIST.md`](DT510-HARDWARE-AUDIT-CHECKLIST.md) — SSOT blocks vs BSP; update as doc/hardware changes. |
| A4 | **Placeholder nodes** | **Done (partial):** `&i2c3` — `bq25792@6b`, `lt9611@39` **disabled** (no pinctrl change). **SE050 / `&i2c4`** deferred until bus present in DT. |

### Tier B — Medium priority (important features, moderate risk)

| ID | Task | Notes |
|----|------|--------|
| B1 | **BQ25792** (charger, I2C3 `0x6B`, `CHGR_INT#`) | Power path; validate GPIO polarity and I2C before enabling charge policies in userspace. |
| B2 | **Digital I/O** (GPIO1 per doc) | GPIO hog or consumer drivers; verify no clash with other `GPIO1` uses. |
| B3 | **CP2108** quad-UART | Often USB-enumerated; DT may only need **reset GPIO** if required. |
| B4 | **SE050** (I2C4 `0x48`) | Aligns with `se05x` / OpTEE story; **coordinate** with security/TEE bring-up — wrong wiring can affect trusted boot. |

### Tier C — Higher effort / higher risk (schedule + validate on hardware)

| ID | Task | Notes |
|----|------|--------|
| C1 | **Ethernet — `&fec1` + KSZ9896** | RGMII + MDIO/DSA as per design; risk of boot hang if PHY/MDIO wrong — incremental bring-up (link up before full bridge). |
| C2 | **Audio vs SSOT** | Spec: TAC5301 (SAI6), TAA5412 (SAI5), TAS6424 (SAI1), plus existing **TAS2563** (SAI3). Current DTS disables SAI1 and does not describe full codec set — **requires architecture decision** and I2C `0x50` resolution vs legacy TCPC node. |
| C3 | **HDMI — LT9611** (I2C3 `0x72`) | Reset/int/fault lines per doc; check pinctrl vs other GPIO users. |
| C4 | **CAN — MCP2518xx on ECSPI2** | **Conflicts** with current **XM125 / ECSPI2** usage in DTS — product choice: radar vs CAN or schematic change. |
| C5 | **GNSS** | Reset line; **conflicts** possible with **XM125** usage on some GPIOs — resolve in SSOT before enabling both. |

### Tier D — Defer / careful batching

| ID | Task | Notes |
|----|------|--------|
| D1 | **Wide pinctrl / hog rewrites** | e.g. pins shared between HDMI int, Wi‑Fi wake, etc. — **only** with schematic sign-off. |
| D2 | **Bulk built-in `CONFIG_*` changes** | Prefer incremental fragments and test images between steps. |

---

## 6. DTS duplication — action item

**Status:** **Implemented (2026-04-13).** Canonical: `recipes-bsp/device-tree/lmp-device-tree/imx8mm-jaguar-dt510.dts`. Kernel recipe: `recipes-kernel/linux/linux-lmp-fslc-imx/imx8mm-jaguar-dt510.dts` → relative symlink to the canonical file.

**Verify on next build:** `bitbake virtual/kernel` / `lmp-device-tree` unpack the symlink correctly; `dtc` / image still contains expected `imx8mm-jaguar-dt510.dtb`.

**Clones:** Windows checkouts without symlink support may need `git config core.symlinks true` or WSL; Linux/macOS are fine.

---

## 7. Known spec ↔ BSP gaps (from first-pass review)

Use [**`DT510-HARDWARE-AUDIT-CHECKLIST.md`**](DT510-HARDWARE-AUDIT-CHECKLIST.md) as the live table; §7 is a short summary.

| Area | SSOT (doc) | BSP today (summary) |
|------|------------|---------------------|
| Driver speaker | TAS2563 @ `0x4C`, SAI3 | Present |
| Analog / mic / class-D | TAC5301, TAA5412, TAS6424 on I2C2 + SAI5/6/1 | Not fully described; SAI1 disabled |
| I2C `0x50` | TAC5301 | Legacy TCPC placeholder @ `0x50` (disabled) — **resolve** |
| Charger | BQ25792 @ `0x6B` | Placeholder `bq25792@6b` **disabled** — enable Tier B1 |
| HDMI | LT9611 (`0x72` 8-bit → `0x39` 7-bit) | Placeholder `lt9611@39` **disabled** — enable Tier C3 |
| Ethernet | KSZ9896 RGMII | `fec1` disabled |
| SE050 | I2C4 `0x48` | Machine feature; **I2C4 child** may be missing in DTS — align |
| CAN | MCP2518xx, ECSPI2 | ECSPI2 disabled (XM125) |
| GNSS / XM125 | Shared GPIO risk | Resolve in SSOT |

---

## 8. Execution rhythm (how we work together)

1. **Kickoff:** Confirm SSOT revision (append date to §2 or errata below).
2. **Per slice:** Pick one Tier A/B item → DT + fragment + `defconfig`/fragment → build → **boot smoke test** → merge.
3. **Reviews:** BSP PRs reference this doc section ID (e.g. “B1”) and the Google Doc section if applicable.
4. **Errata:** Log schematic/doc corrections here before re-editing DTS.

### Errata / revisions (fill in)

| Date | Change |
|------|--------|
| 2026-04-13 | Tier A3 audit checklist; A4 I2C3 placeholders; plan §3/§7 synced. |
| *earlier* | Initial plan from engineering review. |

---

## 9. Boot & regression checklist (minimal)

After each BSP change set:

- [ ] Image builds (`lmp-factory-image` or agreed target).
- [ ] Board boots to userspace / SSH or serial console.
- [ ] `dmesg` — no new critical probe failures on **unchanged** peripherals.
- [ ] If audio/USB/Wi‑Fi touched: run existing **DT510 smoke** (team script or manual) as available.

---

## 10. Owners & contacts

| Role | Name | Notes |
|------|------|--------|
| Hardware SSOT | Ollie Hull | Pinout / schematic clarifications; **lab verification** on DT510 hardware |
| BSP / DT | Alex Lennon | `meta-dynamicdevices-bsp`; implements changes and **posts handoff** on the tracking issue |
| Factory / apps | *assign* | `vixdt` / containers as needed |

---

## 11. Keeping the tracking issue up to date (BSP ↔ lab)

**Tracking issue:** [DynamicDevices/meta-dynamicdevices-bsp#2](https://github.com/DynamicDevices/meta-dynamicdevices-bsp/issues/2)

Use that issue as the **running thread** for “what landed” and “what was verified on hardware.” This markdown file stays the **structured plan**; the issue holds **time-ordered** handoffs and results so nothing relies on chat memory.

### Roles

| Who | Responsibility |
|-----|----------------|
| **Alex (BSP)** | After each meaningful change (or stack of small commits): add an **Implementation** comment on #2 (use template below). Link the **PR or commit SHA** and name the **tier ID** (e.g. A1). Flash/build instructions if non-obvious. |
| **Ollie (lab)** | When a build is available, run **agreed checks** on the DT510 in the hardware lab and add a **Lab result** reply on **the same thread** (template below). Note **PASS / FAIL / PARTIAL**, anomalies, and whether the pinout doc needs errata. |

### Cadence (lightweight)

1. **Implement** → merge to `main` (or share a PR build for early test).
2. **Comment on #2** (Implementation) — same day.
3. **Ollie tests** when the image is on the bench — **Lab result** comment.
4. **Update this doc** (PR): errata (§8), **lab log** (below), or tier notes — so the repo stays auditable.

### Comment template — Implementation (Alex)

Paste into [#2](https://github.com/DynamicDevices/meta-dynamicdevices-bsp/issues/2):

```text
### Implementation — [Tier XX] short title

- **Commit / PR:** `<sha>` / `#<pr>`
- **Scope:** (1–3 bullets: what changed in DT / kernel / recipes)
- **Image / artifact:** (e.g. Foundries build #, local WIC path, OTA target — whatever Ollie should flash)
- **Please verify in lab:**
  - [ ] Boot / serial or SSH
  - [ ] (specific checks for this change, e.g. `i2cdetect`, interface up, audio path)
- **Risks if any:** (regressions to watch)
```

### Comment template — Lab result (Ollie)

Reply under the matching Implementation thread (or quote it):

```text
### Lab result — [same Tier / title]

- **Build tested:** `<how identified — commit/sha/build #>`
- **Outcome:** PASS | FAIL | PARTIAL
- **Notes:** (what worked, what failed, `dmesg` snippets if useful)
- **Pinout doc / schematic:** OK | needs errata — (details)
```

### Lab verification log (update via PR to this file)

| Date | Tier | Commit / ref | Summary | Lab outcome |
|------|------|--------------|---------|-------------|
| 2026-04-13 | A1–A2 | `d78fe3b` | Single DTS symlink + SSOT header; no hardware change. | N/A — confirm next image builds / boots unchanged. |
| 2026-04-13 | A3–A4 | `66d5c1f` | Audit checklist + disabled `bq25792` / `lt9611` placeholders on `&i2c3`. | Expect boot unchanged; `i2cdetect` may show `6b` / `39` if bus scanned. |

### Tips

- **One Implementation comment per “testable slice”** — avoids Ollie guessing what changed.
- If a change is **software-only** (no lab needed), say so in the Implementation comment and still log “N/A lab” in the table when you update the doc.
- For **FAIL**, open a **sub-issue** or reply with `@mention` only if you need a follow-up fix; keep #2 as the parent tracker.

---

*Last updated: 2026-04-13*
