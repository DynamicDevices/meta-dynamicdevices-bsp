# DT510 — KSZ9896CTXC Ethernet (bring-up)

**Hardware (EE):** the KSZ9896C is strapped for **MIIM** — the SoC’s **MDC** (clock) and **MDIO** (data) go to the switch. That is the usual **Clause 22/45** management pair (often called “the MDIO bus”). **I2C and SPI** are the *other* strap options for the *same* two balls; the board is **not** using I2C for switch management in this product.

**Linux / mainline:** the **Microchip DSA** driver for `microchip,ksz9896` in vanilla Linux attaches with **`devm_regmap_init_i2c()`** or **SPI** (`ksz9477_i2c.c` / `ksz_spi.c`). There is **no** in-tree `ksz…` DSA front-end that uses **FEC’s MDIO** as the primary register bus for the 9896. MIIM is still used by the driver stack **indirectly** in some I2C/SPI designs (internal PHY access), not as a substitute for the I2C regmap on a pure-MDIO strap.

**Implemented DT (`imx8mm-jaguar-dt510.dts`):**

- **`&iomuxc`:** `pinctrl_fec1_dt510` — RGMII + MDC/MDIO, aligned with Ollie’s ENET1 block.
- **`&fec1`:** `pinctrl-0`, `phy-mode = "rgmii-id"`, **`fixed-link` 1G** to the switch **CPU** port, **`mdio`** subnode (empty bus placeholder for MIIM; **no** `ksz9896` on I2C).
- **`&i2c1`:** **no** KSZ child — the switch is **not** on I2C for this build.

**Implications:** there is **no** `lan1`… DSA user ports from `ksz9477` until one of: hardware adds **I2C** (strap **01**) to a SoC I2C master and the node returns; **SPI** strap + SPI DT; a **downstream/OO** driver that bit-bangs or speaks switch management over the supplied MDIO; or **NXP/Microchip**-specific integration beyond this doc.

**Sideband GPIOs (PME# / INTR# / RST#):** same physical balls as SAI1/TAS6424 pinctrl in current DT — see previous notes; `reset-gpios` for the switch not wired without an EE/SAI1 trade-off.

## Build → flash → test (short)

1. Pin BSP / manifest per `conf/DT510-HARDWARE-BRINGUP.md`.  
2. Build **`imx8mm-jaguar-dt510`**.  
3. On device: `dmesg | grep -iE 'fec|mdio'`, `ip link` — expect a single **FEC**-backed link (e.g. `end0` / `eth0`), not DSA `lan*`.  
4. `i2cdetect` will **not** show the KSZ at `0x5F` (correct for MIIM).  
5. RGMII timing: if link misbehaves, tune `phy-mode` / delays per PCB (see NXP KSZ + RGMII threads).

## References

- `Documentation/devicetree/bindings/net/dsa/microchip,ksz.yaml`
- `linux/drivers/net/dsa/microchip/ksz9477_i2c.c` (I2C regmap; **not** used when HW is MIIM-only)
- Microchip **KSZ9896C** DS00002390A — **Section 3.2.1** straps, **4.9** management interfaces
- `docs/DT510-BSP-PROJECT-PLAN.md` — Tier **C1** Ethernet
