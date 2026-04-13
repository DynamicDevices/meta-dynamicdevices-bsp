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
| **`vixdt` / Foundries factory** | Factory images, containers, `vix-apps`; not the primary place for kernel DTS, but coordinates with BSP for OTA and apps. |

**Key paths inside this BSP layer (relative to repo root):**

- Canonical DT for Factory/LmP flows: `recipes-bsp/device-tree/lmp-device-tree/imx8mm-jaguar-dt510.dts`
- Kernel recipe also carries a copy: `recipes-kernel/linux/linux-lmp-fslc-imx/imx8mm-jaguar-dt510.dts`

**Single-DTS policy:** Those two files must **not** diverge. Today they are **duplicate files** (same content); **replace one with a symlink** to the other (see §6) so edits happen in one place only.

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
| A1 | **Single DTS source** | Symlink `linux-lmp-fslc-imx/imx8mm-jaguar-dt510.dts` → `lmp-device-tree` copy (or the reverse); document canonical path in a one-line comment near the top of the DTS. |
| A2 | **SSOT header in DTS** | Comment block: reference Google Doc + date/revision + “exceptions” list if any. |
| A3 | **Audit spreadsheet / checklist** | For each major block in the doc: bus, address, DT node name, driver, `CONFIG` fragment, owner, **tier**, **status**. |
| A4 | **Placeholder nodes** | Where safe, add **disabled** placeholders (`status = "disabled"`) for future IP **without** reallocating pinctrl from live peripherals until validated. |

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

**Problem:** Two identical copies of `imx8mm-jaguar-dt510.dts` exist (different inodes); edits can drift.

**Action:** Choose **one** canonical file (recommended: `recipes-bsp/device-tree/lmp-device-tree/imx8mm-jaguar-dt510.dts`). Replace the kernel-recipe copy with a **relative symlink**. Ensure Git symlink handling is acceptable for all clones (`core.symlinks`).

**Verify after change:** `bitbake -e virtual/kernel` / `lmp-device-tree` paths still pick up the file; local `git status` shows symlink as expected.

---

## 7. Known spec ↔ BSP gaps (from first-pass review)

Use this as the backlog; refine against the latest Google Doc revision.

| Area | SSOT (doc) | BSP today (summary) |
|------|------------|---------------------|
| Driver speaker | TAS2563 @ `0x4C`, SAI3 | Present |
| Analog / mic / class-D | TAC5301, TAA5412, TAS6424 on I2C2 + SAI5/6/1 | Not fully described; SAI1 disabled |
| I2C `0x50` | TAC5301 | Legacy TCPC placeholder @ `0x50` (disabled) — **resolve** |
| Charger | BQ25792 @ `0x6B` | Not in DTS |
| HDMI | LT9611 @ `0x72` | Not in DTS |
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
| *—* | *Initial plan from engineering review.* |

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
| Hardware SSOT | Ollie Hull | Pinout / schematic clarifications |
| BSP / DT | Alex Lennon | `meta-dynamicdevices-bsp` |
| Factory / apps | *assign* | `vixdt` / containers as needed |

---

*Last updated: 2026-04-13*
