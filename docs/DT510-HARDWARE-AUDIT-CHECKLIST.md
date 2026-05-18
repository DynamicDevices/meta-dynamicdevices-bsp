# DT510 hardware audit checklist (SSOT ↔ BSP)

**Purpose:** Track each major block from the [VIX DT510 hardware SSOT](https://docs.google.com/document/d/1dlVcfW7SrOifR-rGjkJnVbnQBO4uU8HeS1MEfDmgcYE/edit?usp=sharing) against **`imx8mm-jaguar-dt510.dts`** and kernel fragments. Update as the doc or board changes.

**Milestone:** [Project plan §5 Tier A](DT510-BSP-PROJECT-PLAN.md#tier-a--do-first-high-value-low-boot-risk) is **complete** on `main` (test tag **`dt510-tier-a-test-1`**). Interim lab boards validated boot/software; **full SSOT ↔ bench checks** target **prototype hardware** when available.

**Related:** [`DT510-BSP-PROJECT-PLAN.md`](DT510-BSP-PROJECT-PLAN.md) (**§3 — serial debug UART / `ttymxc1` vs MCU UART4**) · **Kernel `SRC_URI` / patch sunset:** [`KERNEL_PATCH_QUEUE.md`](KERNEL_PATCH_QUEUE.md) · **I²C bus / runtime status (update per build):** [`DT510-HARDWARE-I2C-STATUS.md`](DT510-HARDWARE-I2C-STATUS.md) · **Auracast / LE Audio (IW612):** [`DT510-AURACAST-LE-AUDIO.md`](DT510-AURACAST-LE-AUDIO.md) · **TAS6424 class-D — “Tannoy” ALSA (`tannoys`, `tannoy_slot*`):** [`DT510-TAS6424-TANNOY-ALSA.md`](DT510-TAS6424-TANNOY-ALSA.md) · **TAS2563 driver-speaker ALSA (`driver_*`):** [`DT510-TAS2563-DRIVER-SPEAKER-ALSA.md`](DT510-TAS2563-DRIVER-SPEAKER-ALSA.md) · **TAC5301 analog (`audio_loop` / `aux`):** [`DT510-TAC5301-AUDIO-LOOP-ALSA.md`](DT510-TAC5301-AUDIO-LOOP-ALSA.md) · **TAA5412 “Driver Mic” (`driver_mic`):** [`DT510-TAA5412-DRIVER-MIC-ALSA.md`](DT510-TAA5412-DRIVER-MIC-ALSA.md) · Tool reference: [`reference/dt510-ollie-tool-generated/`](reference/dt510-ollie-tool-generated/) · **Sentai vs DT510:** [§ below](#sentai-vs-dt510-product-clarification)

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

**CAN, GNSS, Ethernet switch, full audio codec set, HDMI** depend on **what is fitted** — not a single global “Sentai yes / DT510 no” flag. **ECSPI2:** on Sentai the XM125 GPIO story used those pins; on DT510 **`&ecspi2`** is **`okay`** with **`can0`** (**MCP251863**). **2026-05-06:** **`mcp251xfd`** + **`can0`** validated in lab after DTS **20 MHz** crystal / **10 MHz** SPI — driver and interface bring-up OK; **on-air** traffic still depends on bench wiring / bitrate / termination — see plan tier C4/C5 and **`meta-subscriber-overrides/docs/DT510-HARDWARE-BRINGUP.md`**.

| SSOT block | Bus / address (SSOT) | BSP status | Notes / DT / driver | Plan tier |
|------------|----------------------|------------|----------------------|-----------|
| Analog audio **TAC5301** | I2C2 `0x50`, SAI6 | **validated (lab)** | **`tac5301@50`**, **`sound-tac5301`** (`tac5301-codec`). **`alsa-state`** **`audio_loop`** (playback / **cabin loop output**) and **`aux`** (capture / **reserved aux input**) — **`asym`** split; **`tac5301codec`** (**[`DT510-TAC5301-AUDIO-LOOP-ALSA.md`](DT510-TAC5301-AUDIO-LOOP-ALSA.md)**). **`&sai6`** **without** `fsl,sai-synchronous-rx`. **BCLK only** (no MCLK). Fallback: **`plughw:*,0`** if card index moves. | C2 |
| Driver speaker **TAS2563** | I2C2 `0x4C`, SAI3 | present | `tas2563@4c`, `sound-tas2563`, `&sai3` — **digital / mono path**; **`alsa-state`**: **`driver_speaker`**, **`drivers`**, **`driver_slot`** / **`driver_out`** + **`tas2563-init`** (card **`tas2563audio`**) — [§ TAS2563](#tas2563-q1-driver-speaker-codec) · **`docs/DT510-TAS2563-DRIVER-SPEAKER-ALSA.md`** | — |
| Mic **TAA5412** | I2C2 `0x51` | partial | DTS: **`taa5412@51`**, **`&sai5`** + **`pinctrl_sai5_taa5412`**, **`sound-taa5412`**; kernel: **`taa5412`** + **`snd_soc_pcm6240`**. **Friendly ALSA (when card present):** **`arecord -D driver_mic`** (**capture-only **`asym`** “**Driver Mic**”) — **`docs/DT510-TAA5412-DRIVER-MIC-ALSA.md`**. **Lab 2026-05-06** (factory **307**): I2C **`1-0051`** / name **`taa5412`** OK; **`taa5412-codec`** ALSA card **missing** — **`dmesg`:** **`&micfil`** (**`fsl,imx8mm-micfil`**, `30080000.audio-controller`) claimed **SAI5_RXC** before **`&sai5`** → **`sound-taa5412` deferred probe**. **BSP:** **`&micfil { status = "disabled"; };`** on DT510 (EVK PDM not used). **IRQ / driver:** **`pcm6240-lmp/0002-asoc-pcm6240-optional-interrupt-dt510.patch`** — when **`interrupts`** are absent in DTS, probe continues (**no bogus irq-gpio dev_err** on boards without codec IRQ wired). Card still needs TI **`taa5412-i2c-1-1dev.bin`**. **Post-micfil fix:** if card still missing, check **`sudo dmesg`** for **`taa5412-i2c-1-1dev.bin`** / **`request_firmware`** **`-2`** — vendor blob not in image; see **`firmware-taa5412`** (**`firmware-taa5412_1.0.bb.disabled`**) + **`README.bin-provenance.md`**. **After reflash + FW:** confirm **`/proc/asound/cards`**, **`arecord -l`**, **`arecord -D driver_mic`** smoke. **IN1/IN2 differential:** not described in DTS — [§ Codec notes](#codec--amp--dt-vs-hardware-engineering-notes-2026-05-06) | C2 |
| Class-D **TAS6424** | I2C2 `0x6A`, SAI1 | **validated (lab)** — **userspace ALSA “Tannoy” path** | **`tas6424@6a` okay** + **`sound-tas6424`** (`tas6424-classd`). **`alsa-state`**: **`/etc/asound.conf`** (`tannoys`, **`tannoy_slot2`/`slot3`**, **`tannoy_both_*`**, **`tannoy_all`**) + **`tas6424-init`**; card short id **`tas6424classd`**. IEC **2–3** = product Tannoys; **TAS6422** migration reshapes slots → **see** [`DT510-TAS6424-TANNOY-ALSA.md`](DT510-TAS6424-TANNOY-ALSA.md). **`tas6424_hi_rail`** SSOT placeholder; **`&micfil` disabled**. | C2 |
| Charger **BQ25792** | I2C3 `0x6B`, `CHGR_INT#` | **partial (validate probe)** | **`bq25792@6b` enabled** + `simple-battery`; BSP kernel patches **0010–0024** (BQ25703A stack + binding import + Patchew v6 BQ25792) when **`bq25792-charger`** — **`git am`** checked on fslc **`97812d71`**; re-verify on your **`SRCREV`**. **CHGR_INT#** in DTS (GPIO4_IO9). Lab: **`i2c-dev`** on **`i2c-2`**. **Issue #3.** | B1 |
| HDMI **LT9611** | I2C3 — SSOT `0x72` (8-bit) → DT **7-bit `0x39`** | placeholder | `lt9611@39` **disabled** in DTS — enable Tier C3 | C3 |
| Auth **SE050** | I2C4 `0x48` | **aligned with stack** | OpTEE **`CFG_CORE_SE05X_I2C_BUS=3`** = **`&i2c4`** (same as Sentai). Machine `se05x` + OEFID set. Optional: explicit DT node — see [`DT510-SE050.md`](DT510-SE050.md) | B4 |
| **MCP2518xx** CAN | ECSPI2 + GPIO | **driver validated (lab)** | **`&ecspi2` okay** — **`can0`** `microchip,mcp251863`; **`CAN_INT#`** GPIO4_IO16, **`CAN_STBY`** GPIO4_IO15; **`mcp251xfd-can`** machine feature. **2026-05-06:** **`mcp251xfd`** probe + **`can0`** after DTS **20 MHz** XTAL + **`spi-max-frequency` 10 MHz**; **`ip link set can0 up type can bitrate …`** for SocketCAN — **on-air** / **`candump`** vs peer still bench follow-up | C4 |
| Ethernet **KSZ9896** | ENET RGMII + **MIIM (MDC/MDIO)** | in DT (validate) | **`&fec1`** RGMII + DSA; **DT510:** **`/delete-node/ mdio`** under **`&fec1`** so **GPIO4_IO22** is **not** EVK PHY **`reset-gpios`** (clashes with **ZB_INT**). Switch-side **`mdio`** remains under DSA per DTS — see **`docs/DT510-ETHERNET-KSZ9896.md`**. | C1 |
| GNSS **NEO-M9V** | UART via **CP2102N** USB + GPIO reset (`gnss-res#`) | **validated (lab)** | **2026-05-05:** NMEA fix with antenna (raw UART). **2026-05-18:** end-to-end on Foundries stack — **`/dev/gnss`** → **`vix-ndtr`** **`onboard_gps`**, **38400**, engineering SSH **`status l`** shows **navigation lock** with antenna. **udev `99-dt510-gnss.rules`:** **`10c4:ea60`** (CP2102N) + **`1546:01a8`/`01a9`** (u-blox USB); BSP **`36f1b22`**, manifest target **378**. **Containers:** **`devices: /dev/gnss`**, **`vix-apps` `6f1935a`**, target **377**. | C5 |
| HDMI misc **HDMI2C1-6C1** | GPIO | partial | Fault line per SSOT — align with LT9611 bring-up | C3 |
| **CP2108** quad-UART (U13, USB HS) | **Internal UART [0–3]** (not `ttyUSBn` order) | **validated (lab)** | **2026-05-16 lab (Michael):** all four UARTs working — **[0]/[1]** **RS-232** (`ttyUSB0`/`ttyUSB1`, IFC **`0x00`**); **[2]/[3]** **RS-485** after NVM **`EnhancedFxn_IFC2`/`IFC3` = `0x0c`** (`cp2108-set-portconfig --rs485-de-invert`); **DE high on TX**, low idle (scope on **`RS485_DE1`/`DE2`**); **`ttyUSB2`/`ttyUSB3`** (**`rs485_tx_bytes`**). **`cp210x`** + **`cp2108-get/set-portconfig`** (**`board-scripts`** / **`cp2108-usb-serial`**). **Port map (O.H.):** **[2]** `RS485_TX1`/`RX1` + **GPIO.10→`RS485_DE1`**; **[3]** `RS485_TX2`/`RX2` + **GPIO.14→`RS485_DE2`**. **Production:** one-time NVM program per unit (§ **CP2108** below). **`QUART_RES#`** **GPIO4_IO5**. **`/dev/serial/by-path`**. | B3 |
| Digital I/O | GPIO1_IO0–9 | **validated (lab)** | **`pinctrl_gpio1_dio_in`** (DI → GPIO1_IO0/1/4/5) + **`pinctrl_gpio1_dio_out`** (DO → IO6–9); EVK **`ir_recv` / `reg_pcie0` / `backlight`** disabled. **SW_PAD (`fsl,pins` 2nd cell, IMX8MMRM Ch.8 — see `imx8mm-sw_pad_ctl-fields.h`):** DI **`0x010`** (**`PE_DIS`**, FSEL fast, **`DSE_X1`**) — no SoC bias; DO **`0x116`** (**`GPIO_STD`**: PE + internal pull-down). Board adds external terminations where required. Scripts when **`dt510-digital-io`**: **`dt510-dio-toggle-outputs`** (DO), **`dt510-dio-poll-inputs`** (DI) + **`libgpiod-tools`**. Lab **2026-05-08**: **DO** toggle and **DI** input paths validated (**O.H.**). | B2 |
| **MAYA‑W276 / IW612** (Wi‑Fi / BT / **802.15.4**) | SDIO + UART (HCI) + ECSPI (ZB MAC-split) | **Wi‑Fi / BT validated (lab)**; ZB DTS + **`zb_mux`** lab | **Wi‑Fi/BT:** **`&usdhc1`** (4‑bit SDIO; **`&usdhc2` disabled** — not EVK SD2); **`&uart1`** HCI **`nxp,88w8997-bt`** with UART3 pads as RTS/CTS; GPIO straps **`BT_WAKE_*`**, **`BT_RST#`**, **`WL_*`**, **`WIFI_PD#`** per `hoggrp` / `imx8mm-jaguar-dt510.dts`. **BT:** **2026‑05** — **`bluetoothctl scan`** finds BLE devices. **802.15.4 / Zigbee:** **ECSPI1** (**`&ecspi1`** **`spidev`**) + **`ZB_INT`** GPIO4_IO22 — **confirmed vs hardware (Ollie Hull)**; **`zb_app`** needs **Sentai private NXP Zigbee RCP FW** alignment (MAC-split ACK / on-air). See **`meta-subscriber-overrides/docs/DT510-HARDWARE-BRINGUP.md`**. | — |
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
- **Userspace ALSA (DT510):** **`imx8mm-jaguar-dt510/asound.conf`** — **`drivers`** (**`pcm`/`ctl`**), **`driver_speaker`** (**`plug`**), **`driver_slot`** / **`driver_out`** (mono → IEC slot 0 **`route`** helpers; **`_tas2563_tdm`** may need tweaking if **`hw`** is not four logical channels — see **`docs/DT510-TAS2563-DRIVER-SPEAKER-ALSA.md`**). **`tas2563-init`** sets **`Speaker Digital Volume`** (env **`TAS2563_BOOT_DVC`**, **`TAS2563_MIXER`**).
- **DTS does not set:** “differential speaker” as a flag — that is **BTL wiring** (OUT+ / OUT− across the load). **`GPIO_ACTIVE_*`** + hog/`output-*` still govern **logical vs electrical** reset/enable lines; derive per net (see project GPIO polarity notes).
- **Revisit when:** smart-amp tuning, USB/RustDesk bridge health, or any SAI3 mux change.

### TAA5412-Q1 (microphone codec — driver-facing “Driver Mic”)

- **DTS covers:** **`taa5412@51`**, **`sound-taa5412`**, **`I²S`**, **`&sai5`** CPU clock master, **`pinctrl_sai5_taa5412`**, **`pinctrl_taa5412_codec_gpio`** (**`GPIO4_IO18`** mux **`SAI1_TXD6`**), **`fsl,sai-mclk-direction-output`** only — **omit `fsl,sai-synchronous-rx`** (**`30050000.sai` probe `-EINVAL`**, **`sound-taa5412` deferred** on **`lmp-350`** vs imx8mm inherited SAI flags; **`&sai5`** aligns with **`&sai1` / `&sai6`**, **not** with **`fsl,sai-synchronous-rx`** on **`&sai3`**). **`&micfil` disabled** so **SAI5_RXC** is not grabbed by EVK PDM.
- **Userspace ALSA (DT510):** **`driver_mic`** — **`type asym`** **capture‑only** ( **`playback.pcm`** **`null`** ) for the **driver / cab microphone** stream; **`amixer -D driver_mic`**. Reference: **`docs/DT510-TAA5412-DRIVER-MIC-ALSA.md`** (**§ Mic input connectivity** — product **I²C / SAI5 / GPIO4_IO18** table vs BSP).
- **DTS / upstream binding do not set:** **`GPIO4_IO18`** (**`SAI1_TXD6`** mux) **function** (**`reset-gpios`**, **`interrupts`**, polarity) until schematic confirms net — **`pinctrl`** on **`taa5412@51`** matches SSOT **pad** (**`0x116`**); **`reset-gpios` / hog** still absent (**may affect I²S bring‑up** depending on TI strap).
- **DTS / upstream binding do not set:** differential vs single-ended **mic** routing for IN1/IN2. The **`snd_soc_pcm6240`** path uses **TI register-block firmware** (`.bin` under firmware search path). Validate **analog mode + levels** against **datasheet + schematic + correct `.bin`**, not DTS alone.
- **Revisit when:** changing **`imx8mm-jaguar-dt510.conf`** **`taa5412`** feature, PCM6240 patch series, or capture topology.

### TAC5301‑Q1 (analog mixer / DAC+ADC — **audio loop output** vs **aux input**)

- **DTS covers:** **`tac5301@50`**, **`compatible = "ti,tac5301"`**, **`sound-tac5301`** (**`simple-audio-card,name = "tac5301-codec"`**) on **`&sai6`**, **`fsl,sai-mclk-direction`** / **no MCLK pad** (**BCLK+FS+DATA** analogue link). BSP analog defaults (**`ti,adc1-single-ended`**, **`ti,out1-mono-se-out1p`**) per **`10-dt510-tac5301-analog-dt-defaults.patch`**.
- **Userspace ALSA (DT510):** **`audio_loop`** = **playback‑only** (cabin audio **loop analogue output** path); **`aux`** = **capture‑only** (input **reserved/unused**, product “aux”— **`type asym`** in **`imx8mm-jaguar-dt510/asound.conf`**). Reference: **`docs/DT510-TAC5301-AUDIO-LOOP-ALSA.md`**.

### TAS6424E-Q1 (class-D — product: two differential outputs on **OUT2** and **OUT3**; 4-ch IC; future **TAS6422E-Q1**)

- **DTS covers:** **`tas6424@6a`**, **`ti,tas6424`**, **`dvdd` / `vbat` / `pvdd`** supplies, **`standby-gpios`** / **`mute-gpios`**, **`sound-tas6424`** (**`simple-audio-card`**, **`format = "i2s"`**), **`&sai1`** with **MCLK + BCLK + FS + TXD0 + TXD1**, **12.288 MHz** parent, **`tas6424_amp_keys`** (FAULT#/WARN#). Coherent for **two logical playback channels** into the amp family driver (**`snd_soc_tas6424`**: `channels_min` 1, `channels_max` 4).
- **DTS does not set:** which **physical** half-bridge pairs (**OUT1…OUT4**) receive **PCM slot 0 / 1**. Product intent (**only OUT2 and OUT3**) must match **TAS6424 serial input mode, strapping, and `PIN_CTRL` (etc.)** per TI data sheet and board netlist. If plain stereo I²S maps to **OUT1/OUT2** instead of **OUT2/OUT3**, fix in **machine / TDM layout** (driver TDM slot logic expects **four contiguous slots** starting at **0** or **4** when TDM is configured) or hardware — **not** a `compatible`-only tweak.
- **Differential outputs:** again **analog BTL** across each load; not a separate DT knob.
- **Userspace ALSA (2026‑05):** **`alsa-state`** installs **`/etc/asound.conf`** with **`tannoys`** + **`tannoy_slot2`/`slot3`** + **`tas6424-init`**. Canonical reference: [`DT510-TAS6424-TANNOY-ALSA.md`](DT510-TAS6424-TANNOY-ALSA.md).
- **TAS6422E-Q1 later:** different part; requires **confirmed kernel `compatible` + driver** (and likely new/updated DT node) — **not** a drop-in rename from **`ti,tas6424`**. **`asound.conf`:** on a **2‑open** PCM, expect **IEC slots 0–1** for the stereo pair — replumb from today’s **`tannoy_slot2`/`slot3`** routes (see **`docs/DT510-TAS6424-TANNOY-ALSA.md`** § Future).

### CP2108 (U13) — quad USB UART (SSOT)

**Purpose:** Eliminate ambiguity between **`cp2108` bridge channel index**, **SiLabs datasheet GPIO.2/.6/.10/.14 (RS‑485 ALT)**, schematic nets, and **Linux `/dev/ttyUSB*`** minors.

**Product wiring (engineering statement, align with schematic *U13*):**

| **Bridge UART index** | **Product interface** | **Data nets** | **RS‑485 bus control / notes** |
|----------------------|------------------------|---------------|----------------------------------|
| **0** | RS‑232 | `RS232TXD1`, `RS232RXD1` | **GPIO.2 / RS485_0** unused (NC); no CP2108 DE for this channel on this SKU |
| **1** | RS‑232 | `RS232TXD2`, `RS232RXD2` | **GPIO.6 / RS485_1** unused (NC) |
| **2** | RS‑485 | `RS485_TX1`, `RS485_RX1` | **GPIO.10 / RS485_2** tied to **`RS485_DE1`** (driver enable pattern per transceiver BOM) |
| **3** | RS‑485 | `RS485_TX2`, `RS485_RX2` | **GPIO.14 / RS485_3** tied to **`RS485_DE2`** |

**Datasheet correlation:** Silicon Labs **[CP2108 datasheet](https://www.silabs.com/documents/public/data-sheets/cp2108-datasheet.pdf)** §**9.3** — **`GPIO.2`, `GPIO.6`, `GPIO.10`, `GPIO.14`** are the pins that **may** assume **RS‑485 transceiver control** behaviour for UART **0–3** respectively. **§3.1.3 Table 3.3** — **`t_ACTIVE`**, RS‑485 active time **after stop bit**, **typical 1 bit-time** (**1/baud_rate**).

**Lab validated (2026-05-16, Michael):** UART **[0]/[1]** **RS-232** and **[2]/[3]** **RS-485** confirmed working on bench hardware. RS-485: after NVM program (**`EnhancedFxn_IFC2`/`IFC3` = `0x0c`**), channels **2** and **3** operate in hardware RS-485 mode with correct **DE polarity** (**DE asserted high during TX**). Confirmed on **`fio@192.168.2.83`** with scope + **`cp2108-get-portconfig`** readback + **`rs485_tx_bytes`** on **`ttyUSB2`/`ttyUSB3`**.

**Linux:** Four **ACM/VCP interfaces** enumerate as **`/dev/ttyUSB0` … `ttyUSB3`** *usually* in bridge order — **confirm per image with** `ls -l /dev/serial/by-path` **before hard-coding.** Lab mapping on CP2108 **`1-1.3`:** IFC2 → **`ttyUSB2`**, IFC3 → **`ttyUSB3`**. **Apps:** **`/dev/etm`** udev symlink → IFC2 (first RS-485, **`RS485_TX1`**) — **`99-dt510-etm.rules`**; NDTR **`etm_connection = wayfarer:/dev/etm:9600:Odd`** (Translink NI; use **`rtig:`** if fleet is RTIGT022). Helper: **`rs485_tx_bytes`** (TX test; DE from bridge NVM, not **`TIOCSRS485`**).

**Customization / factory:** Programming is **SiLabs NVM/customization** (on-chip **OTP/EEPROM**), not Linux device-tree. Use **Simplicity Studio / Xpress Configurator** and **standalone manufacturing utilities** documented in **[AN721](https://www.silabs.com/documents/public/application-notes/AN721.pdf)** (**[GPIO / port AN223](https://www.silabs.com/documents/public/application-notes/an223.pdf)** for pin modes). **Open-source [`cp210x-program`](https://github.com/VCTLabs/cp210x-program)** is packaged for bring-up (**`recipes-devtools/cp210x-program`**) — **no CP2108 guarantee** on the image; validate read/write on hardware before production.

**Production manufacturing (mandatory once per unit):** After board assembly and before RS‑485 system test, program the CP2108 **once** so UART **[2]/[3]** have RS‑485 GPIO alternates and **DT510 DE polarity** (**`EnhancedFxn_IFC2`/`IFC3` = `0x0c`**: `0x04` RS‑485 + `0x08` invert → **DE high during TX**, low when idle). **Not** repeated on every flash of the SoC — only when the bridge NVM is still factory-default or after bridge replacement. **Line procedure (Linux test fixture or manufacturing PC, USB to U13):**

1. `sudo cp2108-get-portconfig > /tmp/cp2108-nvm-before.txt` (record)
2. `sudo cp2108-set-portconfig --rs485-de-invert --dry-run` then `sudo cp2108-set-portconfig --rs485-de-invert -y --bus-reset`
3. `sudo cp2108-get-portconfig` — confirm **IFC2/IFC3 `raw=0x0c`**, IFC0/IFC1 **`0x00`**
4. Scope / traffic: **`rs485_tx_bytes --tty /dev/ttyUSB2`** (and **`ttyUSB3`**) — **DE high during burst** on **`RS485_DE1`/`DE2`** (lab **2026-05-16**)

Equivalent: Xpress Configurator RS‑485 on UART 2 & 3 + polarity invert, then program (same NVM fields). Scripts ship in **`board-scripts`** when **`cp2108-usb-serial`** (`/usr/sbin/cp2108-set-portconfig`, `cp2108-get-portconfig`).

**Reset:** SoC hog **`QUART_RES#`** on **GPIO4_IO5** (**`quart-res-hog`** — see `imx8mm-jaguar-dt510.dts`).

---

## Next actions (from this audit)

**Tier C2 codec order (prototype DT510 — see plan §5 Tier C2 scoped sequence):**

1. **TAS6424** @ `0x6A` / SAI1 — validate on hardware (kernel config, card, rails/GPIOs per #2); then TDM vs I2S if product chooses TDM.
2. **TAA5412** @ I2C2 **`0x51`** / **SAI5** — **DTS + kernel backport landed**; friendly capture **`driver_mic`** (**[`DT510-TAA5412-DRIVER-MIC-ALSA.md`](DT510-TAA5412-DRIVER-MIC-ALSA.md)**). **Next:** lab **`arecord -D driver_mic`**, **`dmesg`** / probe, TI **firmware** blobs if required.
3. **TAC5301** @ I2C2 **`0x50`** / **SAI6** — **friendly ALSA PCMs **`audio_loop`** / **`aux`** (see **`DT510-TAC5301-AUDIO-LOOP-ALSA.md`**); remaining: levels / transducer audible path / future aux wiring validation.

**Other tiers**

4. **Tier B1 (follow-up):** Add **CHGR_INT#** to DTS when GPIO is in SSOT; enable **CONFIG_MFD_BQ257XX** / **CONFIG_CHARGER_BQ257XX** when factory kernel ships **bq257xx** (see **`bq25792-charger.cfg`** notes).
5. **Tier C3:** LT9611 + reset/int pinctrl from SSOT.
6. **Tier B4:** Optional explicit `&i2c4` + SE050 DT node for kernel; **Tier B** closed at **doc** parity with Sentai — see [`DT510-SE050.md`](DT510-SE050.md).

---

*Last updated: **2026-05-16** — **CP2108:** UART **[0]/[1]** RS‑232 + **[2]/[3]** RS‑485 **validated (lab, Michael)**; RS‑485 DE polarity + NVM **`0x0c`** via **`cp2108-set-portconfig --rs485-de-invert`**; manufacturing once-per-unit. Earlier **2026-05-06** — **TAS6424:** [`DT510-TAS6424-TANNOY-ALSA.md`](DT510-TAS6424-TANNOY-ALSA.md); **TAC5301:** [`DT510-TAC5301-AUDIO-LOOP-ALSA.md`](DT510-TAC5301-AUDIO-LOOP-ALSA.md) (**`audio_loop`** / **`aux`**); **TAA5412:** [`DT510-TAA5412-DRIVER-MIC-ALSA.md`](DT510-TAA5412-DRIVER-MIC-ALSA.md) (**`driver_mic`**). SSOT **Class-D row** validated for **`tannoy_*`**. Earlier **2026-05-15** — **§ CP2108:** bridge UART **[0]/[1]** RS‑232; **[2]/[3]** RS‑485 with **`GPIO.10`→`RS485_DE1`**, **`GPIO.14`→`RS485_DE2`** ( **`t_ACTIVE`** 1 bit-time ); factory = **AN721** / NVM. Earlier **2026-05-08** — **Digital I/O:** **O.H.** confirmed **DI** / **DO**; **`pinctrl_gpio1_dio_in`/`_out`**. Earlier **2026-05-06** — codec vs hardware §; TAA5412 lab **307**; **`&micfil` disabled**. Earlier **2026-05-05** — TAC5301; **`fec1`** **`mdio`** delete.*
