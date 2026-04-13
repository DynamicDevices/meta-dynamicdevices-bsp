# DT510 hardware audit checklist (SSOT ↔ BSP)

**Purpose:** Track each major block from the [VIX DT510 hardware SSOT](https://docs.google.com/document/d/1dlVcfW7SrOifR-rGjkJnVbnQBO4uU8HeS1MEfDmgcYE/edit?usp=sharing) against **`imx8mm-jaguar-dt510.dts`** and kernel fragments. Update as the doc or board changes.

**Related:** [`DT510-BSP-PROJECT-PLAN.md`](DT510-BSP-PROJECT-PLAN.md) · Tool reference: [`reference/dt510-ollie-tool-generated/`](reference/dt510-ollie-tool-generated/)

**Legend — BSP status:** present | partial | missing | placeholder | conflict | N/A

| SSOT block | Bus / address (SSOT) | BSP status | Notes / DT / driver | Plan tier |
|------------|----------------------|------------|----------------------|-----------|
| Analog audio **TAC5301** | I2C2 `0x50` | conflict | `tcpc@50` (PTN5110) disabled at same address — **resolve** SSOT vs USB-C TCPC before enabling TAC5301 | C2 |
| Driver speaker **TAS2563** | I2C2 `0x4C`, SAI3 | present | `tas2563@4C`, `sound-tas2563`, `&sai3` | — |
| Mic **TAA5412** | I2C2 `0x51` | missing | SAI5 — not in DTS | C2 |
| Class-D **TAS6424** | I2C2 `0x6A`, SAI1 | missing | `&sai1` disabled | C2 |
| Charger **BQ25792** | I2C3 `0x6B`, `CHGR_INT#` | placeholder | `bq25792@6b` **disabled** in DTS — enable Tier B1 | B1 |
| HDMI **LT9611** | I2C3 — SSOT `0x72` (8-bit) → DT **7-bit `0x39`** | placeholder | `lt9611@39` **disabled** in DTS — enable Tier C3 | C3 |
| Auth **SE050** | I2C4 `0x48` | **aligned with stack** | OpTEE **`CFG_CORE_SE05X_I2C_BUS=3`** = **`&i2c4`** (same as Sentai). Machine `se05x` + OEFID set. Optional: explicit DT node — see [`DT510-SE050.md`](DT510-SE050.md) | B4 |
| **MCP2518xx** CAN | ECSPI2 + GPIO | conflict | `&ecspi2` disabled (XM125) | C4 |
| Ethernet **KSZ9896** | ENET RGMII | missing | `&fec1` disabled | C1 |
| GNSS **NEO-M9V** | GPIO reset | conflict risk | vs XM125 GPIO usage — SSOT | C5 |
| HDMI misc **HDMI2C1-6C1** | GPIO | partial | Fault line per SSOT — align with LT9611 bring-up | C3 |
| **CP2108** quad-UART | GPIO reset | missing | USB enumeration; optional reset GPIO | B3 |
| Digital I/O | GPIO1 | missing | Tier B2 | B2 |
| **MAYA-W276** (Wi‑Fi / BT / 802.15.4) | SDIO, SPI, UART, SAI2 | partial | `&usdhc2`, `&ecspi1`, `&uart1`, `&sai2` etc. | — |
| **STUSB4500** / USB-C | (see I2C conflict) | partial | Distro `stusb4500`; pinctrl vs TAC5301 @ `0x50` | C2 |
| **USB dual UAC2 gadget** | `usbotg1` peripheral + systemd | present | **Simulated / lab** path — see [`DT510-USB-DUAL-AUDIO.md`](DT510-USB-DUAL-AUDIO.md); feature `dt510-usb-dual-audio-autostart` | — |
| **XM125** radar | I2C3 `0x52` | present | Product may choose radar vs CAN — SSOT | — |

\* SSOT “0x72” for LT9611 is treated as **8-bit** address; Linux `reg` uses **7-bit** `0x39`.

---

## Next actions (from this audit)

1. **Resolve I2C2 `0x50`:** one of TAC5301 vs TCPC / STUSB story — hardware + SSOT update.
2. **Tier B1:** Enable BQ25792 + GPIO interrupt + fragment when lab-ready.
3. **Tier C3:** LT9611 + reset/int pinctrl from SSOT.
4. **Tier B4:** Optional explicit `&i2c4` + SE050 DT node for kernel; OpTEE path already uses **I2C4** — see [`DT510-SE050.md`](DT510-SE050.md).

---

*Last updated: 2026-04-13*
