# DT510 — KSZ9896CTXC Ethernet (bring-up)

**Hardware (EE):** the KSZ9896C is strapped for **MIIM** — the SoC’s **MDC** (clock) and **MDIO** (data) go to the switch. That is the usual **Clause 22/45** management pair (often called “the MDIO bus”). **I2C and SPI** are the *other* strap options for the *same* two balls; the board is **not** using I2C for switch management in this product.

**Linux / mainline:** the **Microchip DSA** driver for `microchip,ksz9896` in vanilla Linux attaches with **`devm_regmap_init_i2c()`** or **SPI** (`ksz9477_i2c.c` / `ksz_spi.c`). There is **no** in-tree `ksz…` DSA front-end that uses **FEC’s MDIO** as the primary register bus for the 9896. MIIM is still used by the driver stack **indirectly** in some I2C/SPI designs (internal PHY access), not as a substitute for the I2C regmap on a pure-MDIO strap.

**Implemented DT (`imx8mm-jaguar-dt510.dts`):**

- **`&iomuxc`:** `pinctrl_fec1_dt510` — RGMII + MDC/MDIO, aligned with Ollie’s ENET1 block.
- **`&fec1`:** `pinctrl-0`, `phy-mode = "rgmii-id"`, **`fixed-link` 1G** to the switch **CPU** port, **`mdio`** with five **`ethernet-phy-ieee802.3-c22`** nodes at **addresses 1–5** (internal 1000BASE-T PHYs per datasheet) so **phylib** can attach — **not** the DSA `ksz` driver, just Clause-22 detection/manage for those PHYs. **`&i2c1`:** no KSZ.
- **Kernel:** `ksz9896-mii-phy.cfg` enables `CONFIG_MICREL_PHY` and `CONFIG_MICROCHIP_PHY` (common OUI matches for ksz* PHYs); I²C DSA ksz modules remain off in `ksz9896-ethernet-switch.cfg`.

**Implications:** there is **no** `lan1`… DSA user ports from `ksz9477` until one of: hardware adds **I2C** (strap **01**) to a SoC I2C master and the node returns; **SPI** strap + SPI DT; a **downstream/OO** driver that bit-bangs or speaks switch management over the supplied MDIO; or **NXP/Microchip**-specific integration beyond this doc.

**Sideband GPIOs (PME# / INTR# / RST#):** same physical balls as SAI1/TAS6424 pinctrl in current DT — see previous notes; `reset-gpios` for the switch not wired without an EE/SAI1 trade-off.

## Build → flash → test (short)

1. Pin BSP / manifest per `conf/DT510-HARDWARE-BRINGUP.md`.  
2. Build **`imx8mm-jaguar-dt510`**.  
3. On device: `dmesg | grep -iE 'fec|mdio|phy'`, `ip link` — expect a single **FEC**-backed link (e.g. `end0` / `eth0`), not DSA `lan*`.  
4. **MDIO PHY detection (MIIM):** `ls /sys/bus/mdio/devices` — expect e.g. `0x0bbxxx:01` … `:05` (or `fec:`-prefixed bus name) if the internal PHYs respond; `dmesg` for `-EPROBE_DEFER` / unknown PHY ID (if IDs do not match Micrel/microchip drivers, add the right driver or use `mdio` debug). `i2cdetect` will **not** show the switch at I²C `0x5F` (expected).  
5. RGMII timing: if the CPU link is wrong, tune `phy-mode` / delays (see NXP + KSZ threads). Port links are separate from CPU `fixed-link`.

## References

- `Documentation/devicetree/bindings/net/dsa/microchip,ksz.yaml`
- `linux/drivers/net/dsa/microchip/ksz9477_i2c.c` (I2C regmap; **not** used when HW is MIIM-only)
- Microchip **KSZ9896C** DS00002390A — **Section 3.2.1** straps, **4.9** management interfaces
- `docs/DT510-BSP-PROJECT-PLAN.md` — Tier **C1** Ethernet
