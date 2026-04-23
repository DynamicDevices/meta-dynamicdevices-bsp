# DT510 — KSZ9896CTXC Ethernet (bring-up)

**Status in tree:** RGMII + DSA is wired in `imx8mm-jaguar-dt510.dts` (Tier C1). **You must confirm** the **I2C bus** and **7-bit address** against the schematic — the DTS places the switch on **`&i2c1 @ 0x5f`** as a default strapping; move the node to the correct `&i2cN` and `reg` if the board differs.

## Part

- **Microchip KSZ9896CTXC** — RGMII to i.MX8MM **ENET1** (`fec1`). **MDC/MDIO** on the SoC is still used in hardware for SMI/PHY access; **Linux mainline DSA** uses **I2C** (or SPI) for the switch **register file** — same pattern as NXP community **imx8mn + KSZ9893** ([reference thread](https://community.nxp.com/t5/i-MX-Processors/Device-tree-configuration-for-Imx8M-Nano-with-Ksz9893-ethernet/m-p/1222170)).

## Implemented DT (summary)

- **`&iomuxc`:** `pinctrl_fec1_dt510` — RGMII + MDC/MDIO, EVK-style strengths; **no** `SAI2_RXC`/`GPIO4_IO22` (DT510 uses that pad for **ZB_INT**).
- **`&fec1`:** `pinctrl-0 = <&pinctrl_fec1_dt510>`, `phy-mode = "rgmii-id"`, **`fixed-link` 1G** to the switch CPU port, **`/delete-node/ mdio`**, no external PHY.
- **`&i2c1`:** `ksz9896@5f` with `compatible = "microchip,ksz9896"`, **`ethernet-ports`** and **CPU port 5** → `ethernet = <&fec1>`, `phy-mode = "rgmii-id"`, `fixed-link`.
- **Kernel:** `recipes-kernel/linux/linux-lmp-fslc-imx/imx8mm-jaguar-dt510/ksz9896-ethernet-switch.cfg` — `CONFIG_NET_DSA*`, `CONFIG_NET_DSA_MICROCHIP_KSZ9477_I2C` — included from **`linux-lmp-fslc-imx_%.bbappend`** for **`imx8mm-jaguar-dt510`**.

## RGMII / MDC/MDIO — pin mux (SSOT)

Matches **Ollie** `docs/reference/dt510-ollie-tool-generated/pin_mux.dts` (ENET1 block). See `pinctrl_fec1_dt510` in the DTS for the exact `fsl,pins` list.

## Sideband GPIOs — **not in first bring-up** (TAS6424 conflict)

`ENET_PME#` / `INTR` / `RST` on **GPIO4_IO0, IO1, IO4** conflict with **`pinctrl_sai1_tas6424`**. `reset-gpios` / `interrupts` were **not** added so audio can stay enabled. If the switch stays in reset without a released `RST#`, you need a **hardware** default or a **mux** decision with EE before those lines are described in DT.

## Build → flash → test (short)

1. **Pin BSP** in `lmp-manifest` / one logical change per `conf/DT510-HARDWARE-BRINGUP.md`.  
2. **Build** factory/OTA image for **`imx8mm-jaguar-dt510`**.  
3. On device:
   - `dmesg | grep -iE 'ksz|dsa|fec|ksz9477'`
   - `i2cdetect -y <bus>` — expect the KSZ at the **configured** 7-bit address (placeholder **0x5f** on **bus 0** = `i2c1` if that matches HW). If the part is on another bus, **move the DT node** and rebuild.  
   - `ip link` — expect DSA user ports (e.g. `lan1` …) and a conduit (often `end*`/`eth*`) from DSA.  
4. If link works but **no ping**, check **RGMII internal delays** (see NXP thread: `phy-mode` / `rgmii-id` and KSZ `PORT` XMII delay bits) — that was a common fix for **KSZ9893**; **9896** may need the same class of tuning on your PCB.

## References

- `Documentation/devicetree/bindings/net/dsa/microchip,ksz.yaml`
- `linux/drivers/net/dsa/microchip/ksz9477_i2c.c` (I2C + `compatible` table includes `microchip,ksz9896`)
- `docs/DT510-BSP-PROJECT-PLAN.md` — Tier **C1** Ethernet
