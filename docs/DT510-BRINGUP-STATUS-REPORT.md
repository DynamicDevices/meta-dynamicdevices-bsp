# Vix DT510 — schematic bring-up status

**For:** Michael / Vix programme  
**From:** Dynamic Devices  
**Date:** May 2026  
**Use with:** DT510 **schematic** + Vix **pinout specification** (Ollie Hull)

---

## Bottom line

**Most of the schematic is already working on the bench.** Of the major blocks on the DT510 design, **the majority are proven or running** on lab boards with the current factory image. What remains is a **short, named list** (driver mic close-out, a few connectivity paths, HDMI when you want it)—not a board that still needs to be discovered from scratch.

| | Count |
|---|---|
| **Have** (proven on bench) | **16** |
| **Partly** (working toward product sign-off) | **8** |
| **Not yet** (not enabled in software) | **2** |
| **N/A** (not on Vix DT510 BOM) | **3** |

*Counts match the schematic tables below (26 functional rows + 3 N/A).*

---

## How to use this document

1. Open the **schematic** and walk sheet by sheet.  
2. Find each block in the table below (same order as typical bring-up: power → SoC → comms → audio → misc).  
3. Use the **Status** column: **Have** = exercised on lab hardware; **Partly** = present in software, product test or factory image still to finish; **Not yet** = intentionally not enabled.  
4. If schematic and pinout disagree, **schematic + pinout win**—tell us and we align software.

Lab status = Dynamic Devices on **interim DT510 boards** (May 2026). **Prototype boards** should get the same walk when BOM is frozen.

---

## Schematic walk — have vs not yet

### Core platform

| Schematic block | Ref / key nets | Status | What we know |
|-----------------|----------------|--------|--------------|
| Main SoC | i.MX 8M Mini | **Have** | Boots, eMMC, factory OTA, remote access |
| PMIC | PCA9450, I²C | **Have** | Rails up; board runs |
| Storage | eMMC (USDHC3) | **Have** | Boots from on-board eMMC |
| Debug UART (Linux) | UART2 → debug header | **Have** | Console working (bench wiring verified May 2026) |
| Low-power MCU | MCXC144, UART4 | **Partly** | Link present; field-update workflow in progress |

### Connectivity & positioning

| Schematic block | Ref / key nets | Status | What we know |
|-----------------|----------------|--------|--------------|
| Wi‑Fi | MAYA‑W276 (IW612), SDIO | **Have** | Associated and used on bench |
| Bluetooth | Same module, UART HCI | **Have** | BLE devices discovered in lab |
| Cellular LTE | Quectel-class, USB OTG2; `LTE_RST`, `LTE_OFF`, `SIM_SEL` | **Partly** | Modem and SIM recognised; **mobile data** still to prove |
| Ethernet switch | KSZ9896, RGMII + I²C `0x5f` | **Partly** | **Traffic/forwarding** reported on bench; advanced switch features only if product needs them |
| GNSS | NEO‑M9V, UART; `GNSS_RES#` | **Have** | Valid fix with antenna |
| Zigbee / 802.15.4 | IW612 → ECSPI1, `ZB_INT` | **Partly** | Software stack starts; **over-air product test** still open |

### Field buses & serial

| Schematic block | Ref / key nets | Status | What we know |
|-----------------|----------------|--------|--------------|
| CAN | MCP251863, ECSPI2; `CAN_INT#`, `CAN_STBY` | **Have** | Controller up as `can0`; **vehicle bus** test with partner ECU still to schedule |
| USB quad-UART | **U13** CP2108 | **Have** | All four channels characterised; **RS‑232 + RS‑485 validated on bench (Michael, May 2026)** |
| ↳ RS‑232 | Ch 0–1; `RS232TXD1/RXD1`, `RS232TXD2/RXD2` | **Have** | **Validated (Michael)** — working |
| ↳ RS‑485 | Ch 2–3; `RS485_TX/RX`, `RS485_DE1/DE2` | **Have** | **Validated (Michael)** — timing correct on scope; **one-time factory program on U13** per board (documented) |
| ↳ Bridge reset | `QUART_RES#` | **Have** | Documented in software |

### Vehicle I/O

| Schematic block | Ref / key nets | Status | What we know |
|-----------------|----------------|--------|--------------|
| Digital inputs | GPIO1_IO0, IO1, IO4, IO5 | **Have** | Confirmed with hardware team (May 2026) |
| Digital outputs | GPIO1_IO6–IO9 | **Have** | Confirmed with hardware team (May 2026) |

### Audio

| Schematic block | Ref / key nets | Status | What we know |
|-----------------|----------------|--------|--------------|
| Cabin / loop audio | TAC5301, I²C2 `0x50`, SAI6 | **Have** | Playback/capture path proven |
| Tannoy / PA | TAS6424, I²C2 `0x6A`, SAI1; `AMP_FAULT#`, `AMP_WARN#` | **Have** | Announcement path proven |
| Driver speaker | TAS2563, I²C2 `0x4C`, SAI3 | **Partly** | In factory software; **acoustic sign-off** still to do |
| Driver microphone | TAA5412, I²C2 `0x51`, SAI5 | **Partly** | Chip on I²C bus; **stable record path** on production image is the active close-out |

### Power, display, security

| Schematic block | Ref / key nets | Status | What we know |
|-----------------|----------------|--------|--------------|
| Battery charger | BQ25792, I²C3 `0x6B`; `CHGR_INT#` | **Partly** | Hardware described; **full charger driver** tied to factory kernel release |
| HDMI bridge | LT9611, I²C3 `0x39` | **Not yet** | Held until display path confirmed on BOM |
| HDMI fault / sideband | `HDMI2C1` etc. | **Not yet** | With LT9611 bring-up |
| Secure element | SE050, I²C4 `0x48` | **Partly** | Security stack path documented; product provisioning TBD |

### Not on the DT510 schematic (skip when walking Vix BOM)

| Item | Status | Note |
|------|--------|------|
| USB‑C PD (STUSB4500) | **N/A** | Not populated on DT510 |
| Radar (XM125) | **N/A** | Not on DT510 |
| TCPC @ I²C `0x50` | **N/A** | Removed; address used by **TAC5301** |

---

## The short “not yet” list

Everything else in the table above is **have** or **partly have**. These are the items to focus programme discussion on:

| # | Block | What’s left (plain language) |
|---|--------|------------------------------|
| 1 | **Driver mic (TAA5412)** | Finish factory image + record test (`driver_mic`) |
| 2 | **Zigbee** | RCP firmware on image + over-air validation |
| 3 | **Cellular** | Prove reliable **data** session, not only SIM detected |
| 4 | **Ethernet** | Confirm against your network needs (basic link vs extra switch features) |
| 5 | **Battery charger** | Kernel driver completion on factory release |
| 6 | **Driver speaker** | Acoustic / level sign-off |
| 7 | **Low-power MCU** | Production programming workflow |
| 8 | **HDMI** | Start when display is in scope |
| 9 | **Prototype boards** | Re-walk this table when final BOM hardware lands |

**Manufacturing (not a missing feature):** RS‑485 on **U13** needs a **one-time** CP2108 configuration per assembled board before system test—procedure is written down.

---

## Delivery de-risking (why this is timely)

- **Breadth first:** Most interfaces are already proven in parallel, not queued behind one blocker.  
- **Factory-ready:** Builds are reproducible (Foundries); bench results tie to pinned images.  
- **Line hooks early:** Example—RS‑485 factory step documented before pilot build.  
- **Honest gaps:** Partly / not-yet items are named so schematic review does not re-discover “unknown unknowns.”

---

## Milestone dates (for context)

| When | Highlight |
|------|-----------|
| Apr 2026 | Platform baseline complete; board boots and updates on factory images |
| Early May 2026 | PMIC, Wi‑Fi, Bluetooth, Ethernet path, GNSS |
| 6–8 May 2026 | Tannoy audio, CAN, cabin loop, cellular SIM, digital I/O |
| 16 May 2026 | CP2108 U13: **RS‑232 + RS‑485** validated (**Michael**); factory NVM programming note documented |

---

## Contacts

| Role | Name |
|------|------|
| Hardware (Vix DT510) | Ollie Hull |
| Software / platform | Alex Lennon |

---

*Engineering detail (I²C map, test commands, probe notes): `DT510-HARDWARE-AUDIT-CHECKLIST.md` in the same repository.*
