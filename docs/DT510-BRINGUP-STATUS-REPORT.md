# DT510 board bring-up — status report (for Vix)

**Product:** i.MX 8M Mini **Jaguar DT510** (`imx8mm-jaguar-dt510`)  
**Audience:** Vix / programme stakeholders (summary); engineering detail in linked docs below.  
**Hardware SSOT:** [VIX DT510 pinout / hardware spec](https://docs.google.com/document/d/1dlVcfW7SrOifR-rGjkJnVbnQBO4uU8HeS1MEfDmgcYE/edit?usp=sharing) (Ollie Hull)  
**Software:** `DynamicDevices/meta-dynamicdevices-bsp` + Foundries factory **`vixdt`** (`meta-subscriber-overrides` branch **`main-imx8mm-jaguar-dt510`**)  
**Report basis:** Project plan errata, hardware audit checklist, lab bring-up log, and git history on BSP `main` (through **2026-05-16**).  
**Lab hardware:** Interim DT510 units on the bench (not necessarily final prototype BOM); re-validate on prototype boards when available.

---

## 1. Executive summary

Dynamic Devices has aligned the **DT510 Linux BSP and Foundries factory image** with Ollie Hull’s hardware definition: device tree, kernel fragments, userspace recipes, and lab tooling. **Foundation work (Tier A) is complete** — the board boots Foundries images, OTA/SSH work, and a single canonical DTS drives factory builds.

On **current lab hardware**, multiple subsystems are **bench-validated**: power/PMIC + **Wi‑Fi/BT (IW612)**, **GNSS**, **digital I/O**, **CAN controller bring-up**, **analog loop (TAC5301)**, **class-D / Tannoy path (TAS6424)**, and **both RS‑485 UART channels on the CP2108** (including correct driver-enable polarity and a documented **one-time manufacturing NVM step**).

**Still open** for product-ready sign-off: **Ethernet (KSZ9896) phased plan**, **TAA5412 driver mic** (kernel/firmware/ALSA card polish), **Zigbee end-to-end** (Sentai RCP firmware alignment), **HDMI (LT9611)**, full **charger driver** integration, **cellular data path**, and **prototype-board electrical SSOT review** when units match final BOM.

---

## 2. What we did (by area)

| Area | Status | What was delivered |
|------|--------|-------------------|
| **BSP foundation (Tier A)** | **Done** | Single DTS source; SSOT header; audit checklist; I2C3 placeholders; boot/OTA on lab images; tag **`dt510-tier-a-test-1`**. |
| **Sentai vs DT510 cleanup** | **Done** | Removed XM125, STUSB4500/TCPC@0x50, Sentai USB-C conflicts; DT510-specific machine features. |
| **Wi‑Fi / Bluetooth (IW612)** | **Validated (lab)** | USDHC1 SDIO + dedicated VMMC regulator fix; HCI on UART1; BLE scan works. |
| **Digital I/O (GPIO1)** | **Validated (lab 2026-05-08)** | Pinmux in/out split, pad config, **`dt510-dio-*`** scripts; O.H. confirmed DI/DO. |
| **CP2108 quad UART (U13)** | **Validated (lab 2026-05-16)** | UART 0/1 RS‑232; UART 2/3 RS‑485 with NVM **`EnhancedFxn_IFC2/3 = 0x0c`**; DE high on TX; **`cp2108-get/set-portconfig`** + manufacturing procedure. |
| **GNSS (NEO-M9V)** | **Validated (lab 2026-05-05)** | NMEA fix with antenna; **`/dev/gnss`** udev symlink. |
| **CAN (MCP251863)** | **Driver validated (lab 2026-05-06)** | **`can0`** up; 20 MHz XTAL / 10 MHz SPI in DTS; on-air peer test TBD. |
| **Analog audio TAC5301** | **Validated (lab)** | SAI6 card; **`audio_loop`** / **`aux`** ALSA aliases. |
| **Class-D TAS6424 (Tannoy)** | **Validated (lab 2026-05-06)** | DTS + **`tannoy_*`** ALSA + **`tas6424-init`**; tag **`dt510-tier-c2-tannoy-test-1`**. |
| **Driver speaker TAS2563** | **Present in BSP** | DTS + **`driver_*`** ALSA routes; less full lab narrative than Tannoy. |
| **Driver mic TAA5412** | **Partial** | DTS + PCM6240 kernel backport; I2C probe OK; **`&micfil` disabled**; firmware + **`driver_mic`** card still being closed out on images. |
| **Charger BQ25792** | **Partial** | DTS + patches in tree; ModemManager/cellular separate; kernel charger path needs factory kernel alignment. |
| **Cellular LTE** | **Partial (lab)** | Modem + SIM recognised via **`mmcli`**; bearer/data TBD. |
| **Zigbee (802.15.4)** | **Partial** | ECSPI1 + **`zb_mux`** run; MAC-split / RCP FW alignment with Sentai stack still required. |
| **Ethernet KSZ9896** | **In progress** | Phased plan (simple **`fec1` + fixed-link** first); DSA/switch management later — see **`DT510-ETHERNET-KSZ9896.md`**. |
| **HDMI LT9611** | **Not started** | Placeholder in DTS (**disabled**). |
| **SE050 secure element** | **Doc parity** | OpTEE path same as Sentai; optional explicit DT node not required for parity. |
| **USB dual UAC2 gadget** | **Present (lab/sim)** | Optional autostart feature; separate from production codec path. |
| **PMU / MCXC144** | **In progress** | MCUboot-style PMU firmware pattern added for DT510 line (eink-derived workflow). |

---

## 3. Timeline (from documented milestones)

Dates come from project plan §8 errata, checklist “last updated” notes, bring-up log session headers, and BSP commit history. Where only a month is known, the **first documented** activity in that month is listed.

| Date | Milestone |
|------|-----------|
| **2026-04 (early)** | **Project plan** and **hardware audit checklist** created; tracking via GitHub **`meta-dynamicdevices-bsp#2`**. |
| **2026-04-13** | **Tier A3** audit checklist; **Tier A4** I2C3 placeholders; **Tier B1** `bq25792@6b` enabled in DTS; **Tier C2** TAS6424 DTS steps (SAI1, disabled → enabled with placeholder rail). |
| **2026-04-13** | Removed **TCPC@0x50** / **STUSB4500** (not on DT510); frees I2C **0x50** for TAC5301. |
| **2026-04-13** | **Tier A1–A2:** single canonical DTS + symlink; SSOT comment block in DTS. |
| **2026-04-14** | **Tier A marked complete**; interim lab validation on current boards; tag **`dt510-tier-a-test-1`**. Tier **B** GPIO1 DIO pinmux started; **TAA5412** driver gap documented (needs mainline PCM6240 backport). |
| **2026-04-14** | Codec bring-up order documented: **TAS6424 → TAA5412 → TAC5301**. |
| **2026-04-15** | Sentai inheritance cleanup: XM125, audio-shutdown hog vs TAS2563 reset, USB gadget / TCPC DTC fixes. |
| **2026-04-23** | Foundries bring-up doc baseline: pin BSP SHAs for reproducible factory experiments. |
| **2026-05-04** | Lab: **PMIC + IW612 Wi‑Fi + KSZ9896** reported working together on bench image; **Bluetooth** verified. |
| **2026-05-05** | **GNSS** valid fix with antenna; **Zigbee** mux starts; **TAC5301** enablement work. |
| **2026-05-06** | **TAS6424 / Tannoy** userspace path validated; **CAN** `mcp251xfd` + **`can0`**; **TAA5412** lab on factory build **307** (I2C OK, deferred probe / micfil — later fixed in DTS). |
| **2026-05-06** | **Cellular:** SIM/modem recognised (ModemManager). **Serial console** triage documented (UART2 vs MCU UART4). |
| **2026-05-07** | Serial console confirmed on bench after **hardware** fix (wiring), not BSP change. |
| **2026-05-08** | **Digital I/O** validated (O.H.). |
| **2026-05-15** | CP2108 **port map** documented in BSP (RS‑232 on [0]/[1], RS‑485 + DE on [2]/[3]). |
| **2026-05-16** | **CP2108 RS‑485:** NVM programmed **`0x0c`** on IFC2/3; scope confirms **DE high on TX**; tools **`cp2108-get/set-portconfig`** extended (DE invert flags, manufacturing notes). |

---

## 4. What remains (priority view)

### High impact for product

1. **Prototype hardware sign-off** — Re-run checklist against **final BOM** (not only interim lab boards).  
2. **Ethernet** — Execute phased KSZ9896 plan; prove link, then richer switch features if required.  
3. **TAA5412 driver mic** — Stable **`taa5412-codec`** card, TI firmware on image, **`arecord -D driver_mic`** on production line.  
4. **Zigbee** — Align DT510 with **Sentai NXP RCP / ZBOSS** artefacts; verify on-air, not only mux/PTY.  
5. **CP2108 manufacturing** — Run **one-time** NVM program on each unit (**`cp2108-set-portconfig --rs485-de-invert`**) before RS‑485 system test (or equivalent Xpress Configurator flow).

### Medium / scheduled (Tier C / B follow-up)

- **HDMI LT9611** — Enable when BOM and pinctrl signed off.  
- **BQ25792** — Kernel **`bq257xx`** enablement matched to factory kernel **`SRCREV`**.  
- **Cellular** — Bearer/data validation, policy for **`mmcli`**.  
- **TAS2563** — Full acoustic validation vs product.  
- **Auracast / LE Audio** — Tracker in **`DT510-AURACAST-LE-AUDIO.md`** (HCI smoke exists; product audio path TBD).  
- **CAN** — Peer on bus, termination, application protocol.  
- **PMU (MCXC144)** — Field programming workflow on production line.

### Lower risk / defer

- Optional **SE050** explicit DT node (B4 — doc-only parity today).  
- **TAS6422** silicon migration (IEC slot replumb in ALSA).  
- Wide **pinctrl** changes without schematic review (Tier D).

---

## 5. Factory image and repositories

| Item | Location |
|------|----------|
| BSP (DT, kernel, recipes) | `github.com/DynamicDevices/meta-dynamicdevices-bsp` branch **`main`** |
| Factory subscriber / bring-up log | `source.foundries.io` — **`vixdt/meta-subscriber-overrides`** branch **`main-imx8mm-jaguar-dt510`** |
| Machine | **`imx8mm-jaguar-dt510`** |
| Canonical DTS | `recipes-bsp/device-tree/lmp-device-tree/imx8mm-jaguar-dt510.dts` |
| Build discipline | Pin BSP to a **40-char SHA** (or tag) per experiment; push **`meta-subscriber-overrides`** to trigger Foundries CI |

Example lab image cited in bring-up log: **LmP Dynamic Devices Headless 5.0.9-288-96** class builds (exact build ID varies with CI).

---

## 6. RS‑485 / CP2108 (recent close-out)

Relevant for Vix if the product uses the on-board RS‑485 ports:

| UART (bridge index) | Product | Linux (typical) | NVM `EnhancedFxn` |
|---------------------|---------|-----------------|-------------------|
| 0, 1 | RS‑232 | `ttyUSB0`, `ttyUSB1` | `0x00` |
| 2, 3 | RS‑485 + DE | `ttyUSB2`, `ttyUSB3` | **`0x0c`** (RS‑485 + polarity invert) |

**Manufacturing (once per board):**  
`sudo cp2108-set-portconfig --rs485-de-invert -y --bus-reset`  
then verify with `sudo cp2108-get-portconfig` (expect IFC2/IFC3 **`raw=0x0c`**).

Detail: checklist § **CP2108 (U13)**.

---

## 7. Where to read more (engineering)

| Document | Use for |
|----------|---------|
| [`DT510-BSP-PROJECT-PLAN.md`](DT510-BSP-PROJECT-PLAN.md) | Phased plan (Tier A–D), principles, errata log |
| [`DT510-HARDWARE-AUDIT-CHECKLIST.md`](DT510-HARDWARE-AUDIT-CHECKLIST.md) | Per-block status table (SSOT ↔ BSP) |
| [`meta-subscriber-overrides/docs/DT510-HARDWARE-BRINGUP.md`](https://source.foundries.io/factories/vixdt/meta-subscriber-overrides/src/branch/main-imx8mm-jaguar-dt510/docs/DT510-HARDWARE-BRINGUP.md) | Bench session notes, factory pin SHAs |
| GitHub issue | [meta-dynamicdevices-bsp#2](https://github.com/DynamicDevices/meta-dynamicdevices-bsp/issues/2) — time-ordered handoffs |

Topic guides: `DT510-TAS6424-TANNOY-ALSA.md`, `DT510-TAA5412-DRIVER-MIC-ALSA.md`, `DT510-TAC5301-AUDIO-LOOP-ALSA.md`, `DT510-ETHERNET-KSZ9896.md`, `DT510-AURACAST-LE-AUDIO.md`.

---

## 8. Contacts

| Role | Name |
|------|------|
| Hardware SSOT | Ollie Hull |
| BSP / device tree | Alex Lennon |
| Factory / apps | Dynamic Devices / Vix programme (assign) |

---

*This report is a snapshot for stakeholder communication. For live status, prefer the audit checklist table and project plan §5–§8.*
