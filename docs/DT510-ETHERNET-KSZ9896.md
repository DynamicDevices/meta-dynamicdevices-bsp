# DT510 — KSZ9896CTXC Ethernet (bring-up)

## Phased plan (product intent)

1. **Now — prove the hardware (simple data path):** prioritise a **single CPU-facing Ethernet** (e.g. `end0` / `eth0`), **RGMII + `fixed-link`** to the switch **CPU port**, and **no** DSA / **no** switch management over I²C. The **`&fec1`** block includes an **`mdio`** subnode with **`ethernet-phy@1`…`@5`** (EVK-**like** in having **MDIO + phy** children) for **internal** 1000BASE-T PHY **probe** only — the **CPU** link is still **`fixed-link`**, not **`phy-handle`**, unlike EVK **phy@0** (see §**EVK vs DT510** and **FAQ** above).
2. **Later — richer control plane (track explicitly):** if we need per-port **netdevs** (`lan*`), **VLAN** offload, or **in-kernel** switch config, evaluate **I²C or SPI** strap to the KSZ plus **`microchip,ksz9896`** DSA (or a vendor-supported MDIO-management path if one becomes available). **Do not** block hardware bring-up on that stack.

This doc describes the **phase 1** device tree; §“Simple bring-up (analysis)” below records what that implies and what is **not** a literal EVK copy.

**Hardware (EE):** the KSZ9896C is strapped for **MIIM** — the SoC’s **MDC** (clock) and **MDIO** (data) go to the switch. That is the usual **Clause 22/45** management pair (often called “the MDIO bus”). **I2C and SPI** are the *other* strap options for the *same* two balls; the board is **not** using I2C for switch management in this product.

**Linux / mainline:** the **Microchip DSA** driver for `microchip,ksz9896` in vanilla Linux attaches with **`devm_regmap_init_i2c()`** or **SPI** (`ksz9477_i2c.c` / `ksz_spi.c`). There is **no** in-tree `ksz…` DSA front-end that uses **FEC’s MDIO** as the primary register bus for the 9896. MIIM is still used by the driver stack **indirectly** in some I2C/SPI designs (internal PHY access), not as a substitute for the I2C regmap on a pure-MDIO strap.

**Implemented DT (`imx8mm-jaguar-dt510.dts`):**

- **`&iomuxc`:** `pinctrl_fec1_dt510` — RGMII + MDC/MDIO pads, **Ollie** / SSOT (not EVK `pinctrl_fec1`).
- **`&fec1`:** `pinctrl-0`, `phy-mode = "rgmii-id"`, **`fixed-link` 1G** to the **KSZ CPU** port; **no** `phy-handle` (unlike EVK’s **`phy-handle` → `ethernet-phy@0`**). **`mdio`** with **`ethernet-phy@1`…`@5`** for KSZ **internal** PHYs (Clause 22) — same *idea* as EVK’s **`mdio` + one PHY**, but **addresses** and **no** `phy-handle` on `&fec1` because the **RGMII** path is through the **switch**, not a single dedicated PHY. **`&i2c1`:** no KSZ.
- **Kernel:** `ksz9896-mii-phy.cfg` (PHY drivers) still useful when **MDIO** children return; I²C DSA ksz modules off in `ksz9896-ethernet-switch.cfg`.

## EVK vs DT510 `&fec1` (same SoC, different link)

| | **i.MX8MM EVK** (`imx8mm-evk.dtsi`) | **DT510** |
|---|-------------------------------------|-----------|
| **Topology** | FEC → **one external RGMII PHY** (e.g. QCA) on MDIO | FEC → **RGMII to KSZ** **CPU** port (MAC–MAC path for link purposes) |
| **`phy-mode`** | `rgmii-id` (matches **that** PHY) | `rgmii-id` (same *name*; must match **KSZ + board** delay, not “because EVK”) |
| **`phy-handle` / link partner** | **`phy-handle = <&ethphy0>`** + **`fixed-link` absent** | **`/delete-property/ phy-handle`** (from EVK include); **only** `fixed-link` 1G full for **CPU** port |
| **`fsl,magic-packet`**| **enabled** (PHY feature) | **deleted** (not applicable to this path) |
| **MDIO children** | **`ethernet-phy@0`** + reset, supplies | **`ethernet-phy@1`…`@5`** (internal PHY **probe**); **not** **phy@0** and **not** a replacement for `fixed-link` on the **CPU** port |
| **Pinctrl** | **`pinctrl_fec1`** (NXP pad values + **SAI2_RXC→GPIO4_IO22** for EVK) | **`pinctrl_fec1_dt510`** — **Ollie** **0x116** / **TX_CTL 0x1916**; **no** SAI2→GPIO4_IO22 in this group (DT510 ZB) |

**NXP mainline (browse):** [imx8mm-evk.dtsi `&fec1`](https://raw.githubusercontent.com/torvalds/linux/master/arch/arm64/boot/dts/freescale/imx8mm-evk.dtsi) — search for `&fec1` and `pinctrl_fec1`.

**FAQ — can we use the EVK `&fec1` setup on DT510?** **Not verbatim.** The EVK ties the MAC to **one** external **PHY@0** via **`phy-handle`**, **no** `fixed-link`, **`fsl,magic-packet`**, and **`pinctrl_fec1`**. DT510 ties the MAC to the **KSZ CPU** port (**`fixed-link`**), lists **internal** PHYs at **1…5** for **probe** only, keeps **`phy-handle` deleted**, and uses **`pinctrl_fec1_dt510`**. Copying the EVK block **as-is** would be the wrong link model and **wrong** pins.

**Implications:** there is **no** `lan1`… DSA user ports from `ksz9477` until one of: hardware adds **I2C** (strap **01**) to a SoC I2C master and the node returns; **SPI** strap + SPI DT; a **downstream/OO** driver that bit-bangs or speaks switch management over the supplied MDIO; or **NXP/Microchip**-specific integration beyond this doc.

## Simple bring-up (analysis) — *unmanaged + one CPU IP + no per-port control*

This is the suggested **phase 1** pattern for **hardware prove-out** before a more complex control plane (see *Phased plan* above).

| Idea | On DT510 today | Notes |
|------|----------------|--------|
| **`&fec1` + `fixed-link` (1 G, full) + no `phy-handle`** | **Yes** | Correct model for **MAC (FEC) → RGMII → KSZ CPU port** — there is **no** Clause-22 **PHY in front of** the MAC on that link. The switch port is not “discovered” like an AR8031; **L1 to the rest of the world** is **implicit** in the **switch fabric** + cable PHYs, not a second Linux link on `&fec1`. |
| **`mdio` + phy children** | EVK: **one** child **@0** + **`phy-handle`** | DT510: **five** children **@1…@5** for **KSZ** internal PHYs; **`phy-handle` absent** (CPU RGMII = **`fixed-link`**) |
| **EVK `pinctrl` if RGMII pinout matches** | **Not using EVK FEC** | DT510 **ENET1** is **`pinctrl_fec1_dt510`**, matching **Ollie’s** `pin_mux` / **board** routing — **not** `imx8mm-evk` RGMII. **Only** reuse **EVK** FEC pinctrl if a **schematic/SSOT diff** shows **the same** ball-level ENET1 layout as the EVK; otherwise **SSOT wins** (as in the canonical DTS). |
| **`phy-mode`** | **`rgmii-id`** in tree | Chosen for **RGMII delay** context (KSZ + layout). It is **not** guaranteed identical to the **EVK** (external PHY) choice — tune with **measure** / datasheet if the CPU link misbehaves. |
| **“Unmanaged”** | Straps / default switching | The KSZ can **bridge** with **default** **VID** and forwarding **without** Linux talking **switch** registers. **Phase 1** does **not** add I²C DSA. |

**Summary:** **`&fec1`** is **minimal** for the **CPU** link (`fixed-link` + Ollie pinctrl). **EVK pinctrl** is **not** copied — **SSOT** ENET1 only. **Future:** optional **I²C+DSA** or `mdio` phy children for debug (see *Phased plan*).

**Sideband GPIOs (PME# / INTR# / RST#):** same physical balls as SAI1/TAS6424 pinctrl in current DT — see previous notes; `reset-gpios` for the switch not wired without an EE/SAI1 trade-off.

## Build → flash → test (short)

1. Pin BSP / manifest per `conf/DT510-HARDWARE-BRINGUP.md`.  
2. Build **`imx8mm-jaguar-dt510`**.  
3. On device: `dmesg | grep -iE 'fec|mdio|phy'`, `ip link` — expect a single **FEC**-backed link (e.g. `end0` / `eth0`), not DSA `lan*`.  
4. **MDIO:** `ls /sys/bus/mdio/devices` — expect **PHY @1…@5** if the internal PHYs respond; **`phy-handle` is not** used for the **CPU** RGMII path (`fixed-link`). `i2cdetect` will **not** show the switch at I²C `0x5F` (expected).  
5. RGMII timing: if the CPU link is wrong, tune `phy-mode` / delays (see NXP + KSZ threads). Port links are separate from CPU `fixed-link`.

## References

- `Documentation/devicetree/bindings/net/dsa/microchip,ksz.yaml`
- `linux/drivers/net/dsa/microchip/ksz9477_i2c.c` (I2C regmap; **not** used when HW is MIIM-only)
- Microchip **KSZ9896C** DS00002390A — **Section 3.2.1** straps, **4.9** management interfaces
- `docs/DT510-BSP-PROJECT-PLAN.md` — Tier **C1** Ethernet
