# Kernel patch queue — `imx8mm-jaguar-dt510`

Inventory of **kernel `SRC_URI` fragments** wired for **`MACHINE = imx8mm-jaguar-dt510`** in **`recipes-kernel/linux/linux-lmp-fslc-imx_%.bbappend`** (`SRC_URI:append:imx8mm-jaguar-dt510`). Use this when bumping **`SRCREV_machine`** for **`linux-lmp-fslc-imx`**: determine what still applies, what merged upstream, and what can drop.

**Related:** `imx8mm-jaguar-dt510/bq25792-charger.cfg`, `imx8mm-jaguar-dt510/tac5x1x-lmp/tac5x1x-lmp.cfg`, subscriber **`meta-subscriber-overrides/docs/DT510-HARDWARE-BRINGUP.md`**, BSP **`docs/DT510-HARDWARE-AUDIT-CHECKLIST.md`**.

---

## Maintenance checklist (each kernel pin bump)

1. Record the old and new kernel identity:

   ```bash
   bitbake -e linux-lmp-fslc-imx | grep '^SRCREV'
   ```

2. For **each row** below, either confirm the patch still applies cleanly in **`devshell`** / **`git am`** trial, or mark **`Drop candidate`** with note (upstream SHA or replaced-by).
3. Update **`SRC_URI`** in **`linux-lmp-fslc-imx_%.bbappend`** only after build + smoke on hardware for gated features you care about.
4. Refresh the **Remove when** column when reality changes (do not let this file go stale).

---

## Always appended (`imx8mm-jaguar-dt510`, unconditional)

| Artifact | Type | Purpose | Remove when |
|----------|------|---------|-------------|
| `i2c-dev-interface.cfg` | cfg | `CONFIG_I2C_CHARDEV` — lab **`i2ctools`** on adapter buses | Never needed on production minimal images (could gate later) |
| `imx8mm-sw_pad_ctl.h` | header | Copied next to DTS for **`imx8mm-jaguar-dt510.dts`** pad macro helpers | DT / headers consolidated upstream or DTS stops including |
| `imx8mm-sw_pad_ctl-fields.h` | header | Field layouts for pad control words (GPIO DIO bring-up) | Same |
| `imx8mm-jaguar-dt510/pmic-pca9450.cfg` | cfg | PMIC / **`CONFIG_REGULATOR_PCA9450`** path | Upstream defaultconfig covers DT510 |
| `usb-modem-support.cfg` | cfg | USB modem class drivers | Product removes modems |
| `gpio-keys.cfg` | cfg | GPIO keys driver | Unused on DT510 |
| `imx8mm-jaguar-dt510/video-disable.cfg` | cfg | Disable framebuffer paths not used | Product needs video |
| `imx8mm-jaguar-dt510/wifi-power-management.cfg` | cfg | Wi‑Fi power management Kconfig | Rolled into distro defaults |
| `usb-gadgets.cfg` | cfg | USB gadget stack | Product policy changes |
| `imx8mm-jaguar-dt510/rdc-driver.cfg` | cfg | RDC driver | Upstream + DT alignment |
| `0001-wireless-remove-nl80211-regdom-warning.patch` | patch | Silence nl80211 regdom warning | Fixed in baseline kernel |
| `0004-dts-imx8mm-evkb-fix-duplicate-label.patch` | patch | imx8mm-evkb PMIC label duplicate | Fixed upstream |
| `0003-wireless-wilc1000-disable-scan-progress-message.patch` | patch | Wilc1000 scan spam | Fixed upstream |
| `imx8mm-jaguar-dt510.dts` | dts | Copied into kernel tree for **lmp-base** dev; **LmP/CI use `lmp-device-tree`** | See bbappend NOTE — avoid drift vs **`recipes-bsp/device-tree/lmp-device-tree/imx8mm-jaguar-dt510.dts`** |

**Optional (distro / profiling):**

| Artifact | Gate | Purpose |
|----------|------|---------|
| `imx8mm-jaguar-dt510/usb-audio-gadget.cfg` | `DISTRO != lmp-mfgtool` | USB audio gadget |
| `boot-profiling.cfg` | `ENABLE_BOOT_PROFILING = 1` | Boot profiling |

---

## `MACHINE_FEATURES`–gated fragments

| Feature | Artifacts | Purpose | Remove when |
|---------|-----------|---------|-------------|
| **`cp2108-usb-serial`** | `imx8mm-jaguar-dt510/cp2108-usb-serial.cfg` | CP2108 USB–UART | Hardware / policy |
| **`mcp251xfd-can`** | `imx8mm-jaguar-dt510/mcp251xfd-can.cfg` | MCP251xFD CAN | Same |
| **`tas2563`** | `imx8mm-jaguar-dt510/tas2562-audio-codec.cfg`, `0002-asoc-tas2781-add-tas2563-codec-support.patch` | TAS2563 codec path | Upstream fslc has equivalent |
| **`tas6424`** | `imx8mm-jaguar-dt510/tas6424-audio-codec.cfg`, **`0026-asoc-tas6424-rename-passenger-tannoy-controls.patch`** | TAS6424 class-D; **Tannoy CH1–CH4** names; **TLV dB** retained for lab **`sset -- -17.5dB`** (dropped **`0027`** — bad hunk after **0026**, conflicts with dB workflow) | Upstream accepts renames, or product keeps TLV |
| **`taa5412`** | `pcm6240-lmp/0001-…`, `0002-…`, `pcm6240-audio-codec.cfg` | PCM6240/TAA5412 backport + optional IRQ on DT510 | Mainline + fslc absorb series |
| **`tas2562`** or **`tas2563`** | `0008-asoc-tas2562-fix-format-definition.patch`, `tas2562-driver.cfg` | TAS2562 format / driver Kconfig | Fixed upstream |
| **`ksz9896`** | `ksz9896-ethernet-switch.cfg`, `ksz9896-mii-phy.cfg` | KSZ9896 DSA + MII PHY helpers | Upstream defaults |
| **`tac5x1x-audio`** | `tac5x1x-lmp/tac5x1x-lmp.cfg` + patches **`01`–`07b`, `08`, `09`, `10`** (see below) | TI TAC5301 path (MFD / pinctrl / ASoC / 6.6 compat / DT510 analog defaults) | Lore series merged + fslc aligned — see **`tac5x1x-lmp.cfg`** |
| **`bq25792-charger`** | **`bq25792-charger.cfg`**, **`bq257xx-mfd-kconfig.cfg`**, **`0010`–`0025`** (see below) | **`ti,bq25792`** MFD + charger + regulator on linux-fslc 6.6 | **`drivers/mfd/bq257xx.c`** + bindings + charger/regulator support in factory **`SRCREV`** — track **GitHub `meta-dynamicdevices-bsp` issue #3** |

---

## TI BQ25792 series (`bq25792-charger`)

Applied **in order** after **`0010`–`0012`** base stack; **`0013`** imports binding missing on fslc 6.6; **`0014`–`0024`** Patchew **v6** BQ25792 delta; **`0025`** fixes **`usb_types`** for 6.6 **`power_supply`** API.

| Patch | Subject (abbrev.) | Remove when |
|-------|-------------------|-------------|
| `0010-mfd-bq257xx-add-bq25703a-core-fslc.patch` | MFD `bq257xx` BQ25703A core (fslc context) | Upstream equivalent on pinned **`SRCREV`** |
| `0011-power-supply-bq257xx-charger.patch` | `power: supply: bq257xx` charger | Same |
| `0012-regulator-bq257xx-boost-fslc.patch` | `bq257xx` boost regulator (fslc) | Same |
| `0013-dt-bindings-mfd-ti-bq25703a-Import-binding-from-main.patch` | Import **`ti,bq25703a`** YAML | Binding present in tree |
| `0014-dt-bindings-mfd-ti-bq25703a-Expand-to-include-BQ2579.patch` | Expand binding for BQ2579x / **92** | Same |
| `0015-regulator-bq257xx-Remove-reference-to-the-parent-MFD.patch` | Regulator / MFD split cleanup | Same |
| `0016-regulator-bq257xx-Drop-the-regulator_dev-from-the-dr.patch` | Regulator probe cleanup | Same |
| `0017-regulator-bq257xx-Make-the-OTG-enable-GPIO-really-option.patch` | Optional OTG GPIO | Same |
| `0018-power-supply-bq257xx-Fix-VSYSMIN-clamping-logic.patch` | VSYSMIN clamp fix | Same |
| `0019-power-supply-bq257xx-Make-the-default-current-limit-.patch` | Default input current limit behaviour | Same |
| `0020-power-supply-bq257xx-Consistently-use-indirect-get-s.patch` | Indirect property getters | Same |
| `0021-power-supply-bq257xx-Add-fields-for-charging-and-ove.patch` | Charging / overlay fields | Same |
| `0022-mfd-bq257xx-Add-BQ25792-support.patch` | **BQ25792** MFD / regmap | Same |
| `0023-regulator-bq257xx-Add-support-for-BQ25792.patch` | **BQ25792** OTG / regulator | Same |
| `0024-power-supply-bq257xx-Add-support-for-BQ25792.patch` | **BQ25792** charger integration | Same |
| `0025-power-supply-bq257xx-charger-fix-usb_types-for-kernel-6.6.patch` | **`usb_types`** vs 6.6 API | API stable / upstream fix merged |

---

## TI TAC5x1x / TAC5301 (`tac5x1x-audio`)

Patches listed in **`linux-lmp-fslc-imx_%.bbappend`** (not **`04`** — bindings-only; skipped on fslc — see **`tac5x1x-lmp/tac5x1x-lmp.cfg`**).

| Patch | Role |
|-------|------|
| `01-tac5x1x-lore-263-2.patch` | dt-bindings MFD |
| `02-tac5x1x-lore-263-3.patch` | dt-bindings pinctrl |
| `03-tac5x1x-lore-263-4.patch` | dt-bindings sound codec |
| `05-tac5x1x-lore-263-6.patch` | MFD core |
| `06-tac5x1x-lore-263-7.patch` | Pinctrl driver |
| `07-tac5x1x-lore-263-8.patch` | ASoC codec (Makefile hunks adapted) |
| `07a-tac5x1x-fslc-codecs-makefile-objs.patch` | **`sound/soc/codecs/Makefile`** objs line |
| `07b-tac5x1x-fslc-codecs-makefile-obj.patch` | **`obj-$(CONFIG_SND_SOC_TAC5X1X)`** line |
| `08-tac5x1x-linux-6.6-fslc-compat.patch` | 6.6 API compat |
| `09-tac5x1x-pinctrl-gpiochip-6.6-compat.patch` | GPIO chip / pinctrl compat |
| `10-dt510-tac5301-analog-dt-defaults.patch` | DT510 analog register defaults |

**Remove when:** Lore/mainline + linux-fslc **`SRCREV`** carry equivalent drivers/bindings; re-run **`tac5x1x-lmp.cfg`** fetch/am scripts if refreshing series.

---

## PCM6240 / TAA5412 (`taa5412`)

| Patch | Subject |
|-------|---------|
| `pcm6240-lmp/0001-asoc-pcm6240-import-from-mainline-v6.10.patch` | Backport PCM6240 stack from mainline v6.10 |
| `pcm6240-lmp/0002-asoc-pcm6240-optional-interrupt-dt510.patch` | Missing OF interrupt optional (DT510 SKU) |

---

## Appendix A — Files under `imx8mm-jaguar-dt510/` not in `SRC_URI`

The directory also contains **ASoC debug** patches (`0001-asoc-simple-card-…` through `0005-asoc-pcm-…`) and **`tac5x1x-lmp/patches/04-…`** / **`08-lore-263-9`** that are **not** referenced by **`SRC_URI:append:imx8mm-jaguar-dt510`** as of this queue. Treat as **legacy / reference** unless another recipe or machine pulls them — verify before delete.

---

## Appendix B — BBappend location

Single append definition:

`recipes-kernel/linux/linux-lmp-fslc-imx_%.bbappend` → **`SRC_URI:append:imx8mm-jaguar-dt510`**.
