# DT510 hardware audit checklist (SSOT ↔ BSP)

**Purpose:** Track each major block from the [VIX DT510 hardware SSOT](https://docs.google.com/document/d/1dlVcfW7SrOifR-rGjkJnVbnQBO4uU8HeS1MEfDmgcYE/edit?usp=sharing) against **`imx8mm-jaguar-dt510.dts`** and kernel fragments. Update as the doc or board changes.

**Milestone:** [Project plan §5 Tier A](DT510-BSP-PROJECT-PLAN.md#tier-a--do-first-high-value-low-boot-risk) is **complete** on `main` (test tag **`dt510-tier-a-test-1`**). Interim lab boards validated boot/software; **full SSOT ↔ bench checks** target **prototype hardware** when available.

**Related:** [`DT510-BSP-PROJECT-PLAN.md`](DT510-BSP-PROJECT-PLAN.md) (**§3 — serial debug UART / `ttymxc1` vs MCU UART4**) · **I²C bus / runtime status (update per build):** [`DT510-HARDWARE-I2C-STATUS.md`](DT510-HARDWARE-I2C-STATUS.md) · Tool reference: [`reference/dt510-ollie-tool-generated/`](reference/dt510-ollie-tool-generated/) · **Sentai vs DT510:** [§ below](#sentai-vs-dt510-product-clarification)

**Legend — BSP status:** present | partial | missing | placeholder | conflict | N/A | **validated (lab)** (bench-confirmed on prototype; detail in row)

---

## Sentai vs DT510: product clarification

Machine: **`imx8mm-jaguar-sentai`** vs **`imx8mm-jaguar-dt510`**. Use this when triaging “is this hardware only on Sentai?” or [meta-dynamicdevices-bsp#2](https://github.com/DynamicDevices/meta-dynamicdevices-bsp/issues/2). **BSP references:** `conf/machine/imx8mm-jaguar-sentai.conf`, `conf/machine/imx8mm-jaguar-dt510.conf`, `recipes-bsp/device-tree/lmp-device-tree/imx8mm-jaguar-sentai.dts`, `imx8mm-jaguar-dt510.dts`.

### Different by design in the BSP

| Topic | Sentai | DT510 |
|--------|--------|--------|
| **Acconeer XM125 radar** | `MACHINE_FEATURES` includes **`xm125-radar`**; DTS **`xm125@52`** enabled; **`xm125-radar-monitor`** recipe is **`COMPATIBLE_MACHINE = imx8mm-jaguar-sentai`** only | XM125 **not populated**; **`xm125@52`** + **`pinctrl_xm125_radar`** **removed** from DT510 DTS (Sentai only); no **`xm125-radar`** feature |
| **USB dual UAC2 gadget autostart** | Not a DT510-specific machine feature | **`dt510-usb-dual-audio-autostart`** — toggles **boot** autostart of the lab/simulated gadget path (see [`DT510-USB-DUAL-AUDIO.md`](DT510-USB-DUAL-AUDIO.md)) |
| **Charger / HDMI placeholders** | Not in the DT510-vs-Sentai DTS diff as matching disabled nodes | **`bq25792@6b` enabled** (Tier B1 — kernel charger TBD); **`lt9611@39` disabled** — confirm **BOM** when enabling HDMI |
| **STUSB4500 / USB‑C PD** | `MACHINE_FEATURES` **`stusb4500`**; PD firmware / distro feature | **Not on DT510** — IC not populated; **`stusb4500`** removed from `imx8mm-jaguar-dt510.conf` |
| **PTN5110 / TCPC @ `0x50`** | Legacy **`tcpc@50`** in Jaguar DTS variants | **Not on DT510** — node **removed** from `imx8mm-jaguar-dt510.dts`; **`0x50`** reserved for **TAC5301** per SSOT |

### Same `MACHINE_FEATURES` stack in both machine configs (not Sentai-only)

Both append **`nxpiw612-sdio`** and **`zigbee`**, plus the same **`se05x`** / **`SE05X_OEFID`** pattern (when not local-dev). **Sentai** uses **`tas2562`** (smart amp feature stack); **DT510** uses **`tas2563`** + **`tas6424`** + **`tac5x1x-audio`** (see `imx8mm-jaguar-dt510.conf`). **Sentai** also enables **`stusb4500`** (`MACHINE_FEATURES`); **DT510 does not** — no STUSB4500 USB‑PD IC on board (not USB‑C powered). Wi‑Fi, Zigbee, amp, and SE050-class bring-up are not Sentai-only; **USB‑PD** is.

**Product check:** `imx8mm-jaguar-dt510.conf` notes Wi‑Fi may still follow **Sentai for demo** until new hardware — confirm whether DT510 **hardware** matches Sentai or only the **software** profile.

### Historical (Sentai DTS comments only)

Sentai comments refer to **BGT 60TR13C** radar **replaced by XM125** during bring-up. That is **lineage** on older Sentai work, not an assumption for DT510. Useful when reconciling **old Sentai boards** vs current BOM.

### Open by SKU (use the table below + project plan)

**CAN, GNSS, Ethernet switch, full audio codec set, HDMI** depend on **what is fitted** — not a single global “Sentai yes / DT510 no” flag. **ECSPI2:** on Sentai the XM125 GPIO story used those pins; on DT510 **`&ecspi2`** is **`okay`** with **`can0`** (**MCP251863**). **2026-05-06:** **`mcp251xfd`** + **`can0`** validated in lab after DTS **20 MHz** crystal / **10 MHz** SPI — driver and interface bring-up OK; **on-air** traffic still depends on bench wiring / bitrate / termination — see plan tier C4/C5 and **`meta-subscriber-overrides/conf/DT510-HARDWARE-BRINGUP.md`**.

| SSOT block | Bus / address (SSOT) | BSP status | Notes / DT / driver | Plan tier |
|------------|----------------------|------------|----------------------|-----------|
| Analog audio **TAC5301** | I2C2 `0x50`, SAI6 | **validated (lab)** | **`tac5301@50`**, **`sound-tac5301`** (`tac5301-codec`); **`&sai6`** **without** `fsl,sai-synchronous-rx` so **`fsl-sai`** probes (BSP **`b216a8c+`**, carry **`a7b3d64`** pin). **Wiring:** codec has **BCLK only** (no dedicated **MCLK** pin to TAC5301). **2026‑05‑05:** **`/proc/asound/cards`** shows **`tac5301-codec`**; **`aplay`/`speaker-test`** on **`plughw:3,0`** succeeds (audible output depends on analog path / amp). | C2 |
| Driver speaker **TAS2563** | I2C2 `0x4C`, SAI3 | present | `tas2563@4c`, `sound-tas2563`, `&sai3` — **digital / mono path** (see [§ Codec / amp — DT vs hardware](#codec--amp--dt-vs-hardware-engineering-notes-2026-05-06)) | — |
| Mic **TAA5412** | I2C2 `0x51` | partial | DTS: **`taa5412@51`**, **`&sai5`** + **`pinctrl_sai5_taa5412`**, **`sound-taa5412`**; kernel: **`taa5412`** + **`snd_soc_pcm6240`**. **Lab 2026-05-06** (factory **307**): I2C **`1-0051`** / name **`taa5412`** OK; **`taa5412-codec`** ALSA card **missing** — **`dmesg`:** **`&micfil`** (**`fsl,imx8mm-micfil`**, `30080000.audio-controller`) claimed **SAI5_RXC** before **`&sai5`** → **`sound-taa5412` deferred probe**. **BSP:** **`&micfil { status = "disabled"; };`** on DT510 (EVK PDM not used). **After reflash:** confirm **`/proc/asound/cards`**, **`arecord -l`**, TI firmware if required. **IN1/IN2 differential:** not described in DTS — [§ Codec notes](#codec--amp--dt-vs-hardware-engineering-notes-2026-05-06) | C2 |
| Class-D **TAS6424** | I2C2 `0x6A`, SAI1 | **enabled (validate)** | **`tas6424@6a` okay** + **`sound-tas6424`** (`tas6424-classd`); **`tas6424_hi_rail`** placeholder for vbat/pvdd — **confirm SSOT**; **`&sai1` okay** + `pinctrl_sai1_tas6424` (**TXD0+TXD1**); **`&micfil` / `sound-micfil` disabled**; `CONFIG_SND_SOC_TAS6424=m`. **OUT2/OUT3-only / TAS6422 migration:** [§ Codec notes](#codec--amp--dt-vs-hardware-engineering-notes-2026-05-06) | C2 |
| Charger **BQ25792** | I2C3 `0x6B`, `CHGR_INT#` | **partial (validate probe)** | **`bq25792@6b` enabled** + `simple-battery`; BSP kernel patches **0010–0024** (BQ25703A stack + binding import + Patchew v6 BQ25792) when **`bq25792-charger`** — **`git am`** checked on fslc **`97812d71`**; re-verify on your **`SRCREV`**. **CHGR_INT#** in DTS (GPIO4_IO9). Lab: **`i2c-dev`** on **`i2c-2`**. **Issue #3.** | B1 |
| HDMI **LT9611** | I2C3 — SSOT `0x72` (8-bit) → DT **7-bit `0x39`** | placeholder | `lt9611@39` **disabled** in DTS — enable Tier C3 | C3 |
| Auth **SE050** | I2C4 `0x48` | **aligned with stack** | OpTEE **`CFG_CORE_SE05X_I2C_BUS=3`** = **`&i2c4`** (same as Sentai). Machine `se05x` + OEFID set. Optional: explicit DT node — see [`DT510-SE050.md`](DT510-SE050.md) | B4 |
| **MCP2518xx** CAN | ECSPI2 + GPIO | **driver validated (lab)** | **`&ecspi2` okay** — **`can0`** `microchip,mcp251863`; **`CAN_INT#`** GPIO4_IO16, **`CAN_STBY`** GPIO4_IO15; **`mcp251xfd-can`** machine feature. **2026-05-06:** **`mcp251xfd`** probe + **`can0`** after DTS **20 MHz** XTAL + **`spi-max-frequency` 10 MHz**; **`ip link set can0 up type can bitrate …`** for SocketCAN — **on-air** / **`candump`** vs peer still bench follow-up | C4 |
| Ethernet **KSZ9896** | ENET RGMII + **MIIM (MDC/MDIO)** | in DT (validate) | **`&fec1`** RGMII + DSA; **DT510:** **`/delete-node/ mdio`** under **`&fec1`** so **GPIO4_IO22** is **not** EVK PHY **`reset-gpios`** (clashes with **ZB_INT**). Switch-side **`mdio`** remains under DSA per DTS — see **`docs/DT510-ETHERNET-KSZ9896.md`**. | C1 |
| GNSS **NEO-M9V** | UART NMEA + GPIO reset (`gnss-res#`) | **validated (lab)** | **2026-05-05:** antenna connected; NMEA shows valid fix (`RMC`/`GLL` **A**, `GGA` fix quality, `GSA` 3D, multiple sats used). SSOT reset hog unchanged. | C5 |
| HDMI misc **HDMI2C1-6C1** | GPIO | partial | Fault line per SSOT — align with LT9611 bring-up | C3 |
| **CP2108** quad-UART | GPIO reset | **doc / optional DT** | USB enumeration; DTS comment — add GPIO when SSOT names reset | B3 |
| Digital I/O | GPIO1_IO0–9 | **partial** | **`pinctrl_gpio1_dio`** + EVK **`ir_recv` / `reg_pcie0` / `backlight`** disabled; **SW_PAD:** **`IMX8MM_PAD_GPIO_DEFAULT`** (see **`imx8mm-sw_pad_ctl.h`**) — **2026-05-06:** reverted mistaken internal **pull-up** recipe; **board** supplies **external pull-ups** where required. **`dt510-dio-toggle-outputs.sh`** + **`gpioset --toggle`** for DO bring-up (BSP **`libgpiod-tools`**) | B2 |
| **MAYA‑W276 / IW612** (Wi‑Fi / BT / **802.15.4**) | SDIO + UART (HCI) + ECSPI (ZB MAC-split) | **Wi‑Fi / BT validated (lab)**; ZB DTS + **`zb_mux`** lab | **Wi‑Fi/BT:** **`&usdhc1`** (4‑bit SDIO; **`&usdhc2` disabled** — not EVK SD2); **`&uart1`** HCI **`nxp,88w8997-bt`** with UART3 pads as RTS/CTS; GPIO straps **`BT_WAKE_*`**, **`BT_RST#`**, **`WL_*`**, **`WIFI_PD#`** per `hoggrp` / `imx8mm-jaguar-dt510.dts`. **BT:** **2026‑05** — **`bluetoothctl scan`** finds BLE devices. **802.15.4 / Zigbee:** **ECSPI1** (**`&ecspi1`** **`spidev`**) + **`ZB_INT`** GPIO4_IO22 — **confirmed vs hardware (Ollie Hull)**; **`zb_app`** needs **Sentai private NXP Zigbee RCP FW** alignment (MAC-split ACK / on-air). See **`meta-subscriber-overrides/conf/DT510-HARDWARE-BRINGUP.md`**. | — |
| **Cellular LTE** (Quectel **EM05** class) | **USB OTG2** host (`&usbotg2`); LTE_RST / LTE_OFF / SIM_SEL hogs | **partial (lab)** | **2026-05:** ModemManager **`mmcli -m 1`** — modem present, **primary SIM active** (`/SIM/1`), IMSI + operator name readable; earlier **`sim-missing`** seen until reboot/settle. **`cdc-wdm0`** MBIM + **option** ttys. Enable rf with **`mmcli -m 1 --enable`** if state **disabled**; bearer/data/voice **TBD**. Module reported **fixed-dialing** lock — confirm vs SIM/product. | — |
| **STUSB4500** / USB‑C PD | — | **N/A (DT510)** | **Not populated** — no `stusb4500` machine feature; gadget uses **`&usbotg1`** peripheral only (see `DT510-USB-DUAL-AUDIO.md`). **Sentai** retains STUSB4500. | — |
| **USB dual UAC2 gadget** | `usbotg1` peripheral + systemd | present | **Simulated / lab** path — see [`DT510-USB-DUAL-AUDIO.md`](DT510-USB-DUAL-AUDIO.md); feature `dt510-usb-dual-audio-autostart` | — |
| **XM125** radar | — | **N/A (DT510)** | **Sentai only** — not on DT510; **`xm125@52`** node **not present** in `imx8mm-jaguar-dt510.dts` | — |

\* SSOT “0x72” for LT9611 is treated as **8-bit** address; Linux `reg` uses **7-bit** `0x39`.

---

## Codec / amp — DT vs hardware (engineering notes, 2026-05-06)

**Purpose:** Record what **`imx8mm-jaguar-dt510.dts`** actually configures versus what must come from **schematic, TI silicon behaviour, firmware, or ALSA topology** — so future bring-up does not assume a DT property exists when it does not.

### TAS2563-Q1 (driver speaker codec)

- **DTS covers:** `compatible = "ti,tas2563"`, `reg = <0x4c>`, **`ti,channels = <1>`** (mono path from SoC), **`ti,asi-format = <0>`**, **`ti,left-slot` / `ti,right-slot`**, **`sound-tas2563`** on **`&sai3`** with **Profile 8** TDM (**`dai-tdm-slot-num = <4>`**, **`dai-tdm-slot-width = <32>`**), **12.288 MHz** / **AUDIO_PLL1**, **`fsl,sai-synchronous-rx`**, reset + IRQ on GPIO5. Same pattern as **`imx8mm-jaguar-sentai.dts`** for this amp family.
- **DTS does not set:** “differential speaker” as a flag — that is **BTL wiring** (OUT+ / OUT− across the load). **`GPIO_ACTIVE_*`** + hog/`output-*` still govern **logical vs electrical** reset/enable lines; derive per net (see project GPIO polarity notes).
- **Revisit when:** smart-amp tuning, USB/RustDesk bridge health, or any SAI3 mux change.

### TAA5412-Q1 (microphone codec — e.g. two differential inputs on IN1 / IN2)

- **DTS covers:** **`taa5412@51`**, minimal required properties + **`sound-taa5412`** (**I²S**, **`&sai5`** as CPU clock master), **`pinctrl_sai5_taa5412`**, **`&micfil` disabled** so **SAI5_RXC** is not grabbed by EVK PDM (**deferred probe** issue — see table row above).
- **DTS / upstream binding do not set:** differential vs single-ended **mic** routing for IN1/IN2. The **`snd_soc_pcm6240`** path uses **TI register-block firmware** (`.bin` under firmware search path). Validate **analog mode + levels** against **datasheet + schematic + correct `.bin`**, not DTS alone.
- **Revisit when:** changing **`imx8mm-jaguar-dt510.conf`** **`taa5412`** feature, PCM6240 patch series, or capture topology.

### TAS6424E-Q1 (class-D — product: two differential outputs on **OUT2** and **OUT3**; 4-ch IC; future **TAS6422E-Q1**)

- **DTS covers:** **`tas6424@6a`**, **`ti,tas6424`**, **`dvdd` / `vbat` / `pvdd`** supplies, **`standby-gpios`** / **`mute-gpios`**, **`sound-tas6424`** (**`simple-audio-card`**, **`format = "i2s"`**), **`&sai1`** with **MCLK + BCLK + FS + TXD0 + TXD1**, **12.288 MHz** parent, **`tas6424_amp_keys`** (FAULT#/WARN#). Coherent for **two logical playback channels** into the amp family driver (**`snd_soc_tas6424`**: `channels_min` 1, `channels_max` 4).
- **DTS does not set:** which **physical** half-bridge pairs (**OUT1…OUT4**) receive **PCM slot 0 / 1**. Product intent (**only OUT2 and OUT3**) must match **TAS6424 serial input mode, strapping, and `PIN_CTRL` (etc.)** per TI data sheet and board netlist. If plain stereo I²S maps to **OUT1/OUT2** instead of **OUT2/OUT3**, fix in **machine / TDM layout** (driver TDM slot logic expects **four contiguous slots** starting at **0** or **4** when TDM is configured) or hardware — **not** a `compatible`-only tweak.
- **Differential outputs:** again **analog BTL** across each load; not a separate DT knob.
- **TAS6422E-Q1 later:** different part; requires **confirmed kernel `compatible` + driver** (and likely new/updated DT node) — **not** a drop-in rename from **`ti,tas6424`**.

---

## Next actions (from this audit)

**Tier C2 codec order (prototype DT510 — see plan §5 Tier C2 scoped sequence):**

1. **TAS6424** @ `0x6A` / SAI1 — validate on hardware (kernel config, card, rails/GPIOs per #2); then TDM vs I2S if product chooses TDM.
2. **TAA5412** @ I2C2 **`0x51`** / **SAI5** — **DTS + kernel backport landed** (`imx8mm-jaguar-dt510.dts`, **`taa5412`** feature); **next:** lab **`arecord`**, **`dmesg`** / probe, TI **firmware** blobs if required.
3. **TAC5301** @ I2C2 **`0x50`** / **SAI6** — **playback validated (lab 2026‑05)** on pinned BSP; remaining: levels / routing / capture vs product, **`amixer`** / **`alsamixer`** if path is silent at the transducer.

**Other tiers**

4. **Tier B1 (follow-up):** Add **CHGR_INT#** to DTS when GPIO is in SSOT; enable **CONFIG_MFD_BQ257XX** / **CONFIG_CHARGER_BQ257XX** when factory kernel ships **bq257xx** (see **`bq25792-charger.cfg`** notes).
5. **Tier C3:** LT9611 + reset/int pinctrl from SSOT.
6. **Tier B4:** Optional explicit `&i2c4` + SE050 DT node for kernel; **Tier B** closed at **doc** parity with Sentai — see [`DT510-SE050.md`](DT510-SE050.md).

---

*Last updated: 2026-05-06 — **§ Codec / amp — DT vs hardware** added (TAS2563 / TAA5412 / TAS6424 + TAS6422 migration notes). TAA5412 lab on **307**: I2C OK; **`&micfil`** vs **`&sai5`** pin clash + BSP **`&micfil` disabled** note. GPIO1 DIO **`GPIO_DEFAULT`** + external pull-ups (**`DT510-HARDWARE-BRINGUP.md`**). Earlier: 2026-05-05 — TAC5301 lab playback; **`fec1`** **`mdio`** delete; DIO script; pins **`a7b3d64`** / **`2cda7ac`**.*
