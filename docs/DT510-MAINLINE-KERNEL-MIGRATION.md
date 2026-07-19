# DT510 → mainline-based kernel migration (`linux-fslc` 6.12 LTS)

Working doc for moving **`MACHINE = imx8mm-jaguar-dt510`** off the NXP vendor
kernel (**`linux-lmp-fslc-imx`**, NXP's `linux-fslc` fork pinned at 6.6.52) onto
the **community `linux-fslc` 6.12 LTS** (`github.com/Freescale/linux-fslc`,
`KBRANCH=6.12.x+fslc`, `LINUX_VERSION=6.12.13`).

- **Branch:** `experiment/dt510-mainline-kernel` (BSP submodule).
- **Isolation:** this git branch **plus a dedicated Foundries CI branch**. The
  production DT510 factory builds from its own branch, so nothing here touches
  production. Because isolation is at the branch level, the experiment edits the
  existing `imx8mm-jaguar-dt510` machine directly (no separate machine variant).
- **Companion inventory:** `KERNEL_PATCH_QUEUE.md` (the current vendor-kernel
  `SRC_URI` queue this migration trims).

## This is a branch/recipe move, not a repo change

Both the current and target kernels come from **the same upstream tree**,
`github.com/Freescale/linux-fslc`. What changes is the **branch + recipe**:

| | Foundries / production today | This experiment |
|---|---|---|
| Recipe | `linux-lmp-fslc-imx` (`_6.6.bb`, in `meta-lmp`) | `linux-fslc` (`_6.12.bb`, in `meta-freescale`) |
| Upstream repo | `Freescale/linux-fslc` | `Freescale/linux-fslc` (same) |
| Branch | NXP vendor `6.6-*-imx` (~6.6.52) | community `6.12.x+fslc` (6.12.13) |
| Nature | NXP **vendor** kernel | community **mainline-based** LTS |
| Selected by | `meta-lmp` `lmp-machine-custom.inc`: `PREFERRED_PROVIDER_virtual/kernel:mx8mm-nxp-bsp ?= "linux-lmp-fslc-imx"` (DT510 inherits `mx8mm-nxp-bsp`) | `conf/machine/imx8mm-jaguar-dt510.conf` override on this branch |

So the confusion "aren't we already on linux-fslc?" is understandable — the
vendor recipe *does* fetch from `Freescale/linux-fslc`. But it tracks the NXP
`-imx` vendor branch at 6.6, whereas the community `+fslc` branch at 6.12 is the
mainline-based line. The migration moves between those two branches/recipes of
the one tree; it does not change the upstream source.

Note: the newest community `+fslc` branch is `6.12.x+fslc` (6.12 is current —
there is no `6.13`–`6.18` `+fslc`). NXP's vendor side has advanced to
`6.18-*-imx` branches, which matters only if fully shedding BQ25792/TAC5x1x
(upstream at 6.18/~6.17+) ever outweighs staying on a community mainline base.

## Decision (2026-07-19)

Target **`linux-fslc` 6.12 LTS now**, accepting that the two biggest backport
stacks (**BQ25792**, **TAC5x1x/TAC5301**) are **not yet upstream at 6.12** and
must be carried — but as **clean cherry-picks of now-upstream commits**, not
hand-maintained 6.6 backports. Banked wins at 6.12: LTS base, several stacks go
fully in-tree, and the whole class of "6.6-compat" shims disappears.

Rejected for now: waiting for a 6.18-based tree (where BQ25792 + TAC5x1x are
fully upstream). 6.18 is not LTS and is not in `meta-freescale`; revisit when a
≥6.18 fslc/LTS lands — at that point the two stacks drop entirely.

## Patch-queue triage vs. 6.12 (grounded in mainline merge history)

| Stack | # | Mainline merge | In 6.12? | Disposition on `linux-fslc` 6.12 |
|-------|---|----------------|----------|----------------------------------|
| **BQ25792 charger** (`bq257xx` MFD/charger/regulator, `0010`–`0025`) | 16 | **6.18** (`CONFIG_CHARGER_BQ257XX`; Charkov v6/v7, mid-2026) | No | **CARRY** as upstream cherry-picks; drop at ≥6.18 |
| **TAC5x1x / TAC5301** (Lore "263", `01`–`10`) | 11 | ~6.17+ (TI `niranjan.hy`, v1 Mar 2026; Kconfig lists TAC5301) | No | **CARRY** as upstream cherry-picks; drop when merged |
| **TAS2563** (`0002-...tas2781-add-tas2563`) | 1 | **6.8** (moved tas2562→tas2781) | Yes | **DROP** — in-tree; enable via cfg |
| **TAS2562 format fix** (`0008`) | 1 | ≤6.12 (verify) | likely | **DROP** (verify at build) |
| **TAS6424** | cfg | mainline (years) | Yes | **cfg-only** |
| **PCM6240 base import** (`0001-...v6.10`) | 1 | **6.10** | Yes | **DROP** — in-tree |
| **PCM6240 DT510 optional-IRQ** (`0002`) | 1 | DT510-specific | No | **CARRY** (small local delta) |
| **KSZ9896** switch + MII | cfg | mainline (≪6.12) | Yes | **cfg-only** |
| **6.6-compat shims** (`08`/`09` tac compat, `0025` usb_types-6.6) | ~3 | n/a (exist only for 6.6) | — | **DROP** (obsolete at 6.12) |
| **evkb duplicate-label** (`0004`) | 1 | — | moot | **DROP** after DT rebase |
| Cosmetic (`nl80211` regdom, `wilc1000` spam) | 2 | optional | — | drop/keep tiny |

> Note on TAA5412: mainline moved TAA5412/TAA5212 **out of `pcm6240` into the new
> `tac5x1x` driver** (the "263" series' patch 8/8). At 6.12, TAA5412 is still
> handled by in-tree `pcm6240`; once the TAC5x1x series is applied it moves to
> the `tac5x1x` codec. Keep TAA5412 on the `pcm6240` path for the 6.12 baseline.

Net at 6.12: **carry ~27–28** (BQ25792 + TAC5x1x + a couple of DT510 deltas),
**drop the rest** (~12) and shed all 6.6-compat shims.

## Out-of-tree / stack gaps (decide separately, not kernel patches)

DT510 currently rides the full NXP vendor stack via
`require conf/machine/imx8mm-lpddr4-evk.conf`. These are **not** solved by the
kernel swap and need their own decisions:

- **IW612 Wi‑Fi** — NXP `moal`/`mlan` out-of-tree modules (`KERNEL_MODULE_AUTOLOAD`
  `mlan moal`, `firmware-nxp-wifi`). Must build against 6.12, **or** move to
  mainline `nxpwifi`/`mwifiex`-style support. Highest-risk gap.
- **Hantro VPU** (`imx-vpu-hantro*`) and **NXP AFE / VoiceSeeker** (`nxp-afe*`) —
  vendor-kernel-coupled; likely dropped or reworked on a mainline path.
- **SE050 / OP-TEE** (`se05x`) — verify against the 6.12 build.

## DT rebase — audit findings (vs mainline `imx8mm-evkb.dts` → `imx8mm-evk.dtsi`)

Base ground truth: `Freescale/linux-fslc` @ SRCREV `404e5a82` (6.12.x+fslc).
`imx8mm-evkb.dts` exists in mainline but only `#include`s `imx8mm-evk.dtsi`
(**not** `imx8mm-evk.dts`). Audit of every `&label` override + delete in
`imx8mm-jaguar-dt510.dts`:

- **Safe deletes (no-op or resolve):** NXP-vendor codecs `ak4458@10/@12`,
  `ak5558@13`, `ak4497@11` (under `&i2c3`) and root `sound-ak4458/ak5558/ak4497`,
  `regulator-audio-board` are absent in mainline — dtc silently ignores deleting a
  non-existent node/property. `camera@3c`, `gpio@20` (pca6416), `tcpc@50`,
  `sound-micfil/wm8524/spdif/bt-sco`, `hdmi-connector` **do** exist in mainline
  `imx8mm-evk.dtsi`, so those deletes resolve.
- **Base labels that resolve:** `&fec1 &i2c2 &i2c3 &reg_vddext_3v3 &reg_pcie0
  &backlight &mipi_dsi &spdif1 &pcie0 &micfil &snvs_pwrkey &usbotg1` (all in
  mainline `imx8mm-evk.dtsi`); `&sai1/3/5/6 &uart1/3/4 &usdhc1/2/3 &ecspi1/2
  &gpio1-5 &iomuxc &usbotg2` (all in `imx8mm.dtsi`).
- **Self-contained (no base dependency, verified):**
  - **All pinctrl groups are DT510-defined**, including `pinctrl_usdhc3/_100mhz/
    _200mhz` (the eMMC NAND-pin mux) — so the earlier "usdhc3 pinctrl missing from
    evkb" worry is a **non-issue**. Every `pinctrl-0/1/2` reference resolves to a
    self-defined group.
  - **All `*-supply` phandles** point to `&reg_vddext_3v3` (base, present) or the
    self-defined `&tas6424_hi_rail` / `&reg_wifi_sdio_vmmc`. **No** PMIC
    buck/ldo, `&pca6416`, `&osc_32k`, or `&wm8524` dependencies.
### AUDIT COMPLETE — full 1350-line DTS cross-checked. Result: **3 targeted fixes**;
everything else is self-contained (own pinctrl, own regs, supplies only to base
`reg_vddext_3v3`) or already matches mainline. The author wrote defensively and
even anticipated mainline in places (e.g. the `ecspi2 spi@0` note). The three
mainline `of-graph` / label breakages (works today only because the NXP *vendor*
evk.dtsi differs structurally):

1. **`ir-receiver`** (was `&ir_recv { status = "disabled"; }`) — mainline's node is
   **unlabeled** (no `&ir_recv`) → undefined phandle. It also claims `GPIO1_IO13`,
   which DT510 uses for `tas6424_warn` (gpio-keys) → resource clash if left
   enabled. **Fix:** `/delete-node/ ir-receiver;` at root (by node name); drop the
   `&ir_recv` block.
2. **DSI→HDMI graph** — DT510 keeps `hdmi@3d` (adv7535) as `status="disabled"` but
   `/delete-node/`s its peers `hdmi-connector` (root) + `&mipi_dsi { ports }`,
   leaving adv7535's `remote-endpoint = <&hdmi_connector_in>` / `<&dsi_out>`
   dangling. **Fix:** do **not** delete those peers — keep the graph intact and
   inert via `status="disabled"` on `&mipi_dsi` + `hdmi@3d`. All phandles resolve.
3. **MIPI-CSI→camera graph** — DT510 `/delete-node/ camera@3c` (ov5640) but mainline
   `&mipi_csi`'s `imx8mm_mipi_csi_in` endpoint references `<&ov5640_to_mipi_csi2>`
   → dangles. **Fix:** since the camera peer is gone, delete the CSI side too:
   `&mipi_csi { status="disabled"; /delete-node/ ports; };` + `&csi { status="disabled"; };`.

USB-C graph is already clean (both `tcpc@50` and `usbotg1/port` are deleted
together — symmetric). `/delete-node/` of NXP-vendor codecs are safe no-ops.

**Runtime follow-up (not a build blocker):** mainline enables `&lcdif`; DT510 does
not touch it, so with `&mipi_dsi` disabled `lcdif` has no downstream encoder. Fine
for a green *image build*; revisit for actual display bring-up.

## DT rebase finding (2026-07-19) — smaller than expected

Static analysis of the canonical `imx8mm-jaguar-dt510.dts` against the fetched
mainline 6.12 base (`imx8mm.dtsi` + `imx8mm-evk.dtsi` + `imx8mm-evkb.dts`):

- **Every referenced `&label` resolves** in the mainline base or is self-defined
  (the "missing" `i2c`/`i2cN`/`ir_recv` hits were comment-text false positives —
  the DTS even notes *"mainline's node is unlabeled (there is no `&ir_recv`)"*).
- The `/delete-node/` ops that target NXP-vendor-only nodes (`sound-ak4458`,
  `sound-ak5558`, `sound-ak4497`, `regulator-audio-board`, and the `ak*@1x`
  codecs on `&i2c3`) are **by-name deletes → no-ops on mainline** (dtc does not
  error deleting an absent named node). Deletes that target nodes present in
  mainline (`sound-micfil/wm8524/spdif/bt-sco`, `ir-receiver`, `camera@3c`,
  `gpio@20`, `tcpc@50`, `&fec1` mdio/props) still apply correctly.

**Conclusion:** reuse the canonical DTS **unchanged**; the only real work is
**build placement** for mainline's arm64 layout — DTBs are declared in
`freescale/Makefile`, not the top-level `dts/Makefile` (which is `subdir-y`
only). The `linux-fslc` bbappend therefore installs the DTS into `freescale/`,
rewrites its `#include "freescale/imx8mm-evkb.dts"` to the sibling path, and adds
`dtb-$(CONFIG_ARCH_MXC) += imx8mm-jaguar-dt510.dtb` to `freescale/Makefile`.
(Compile still to be confirmed in CI, but no DTS surgery is expected.)

## Forward-port worklist (exact files, 2026-07-19)

Source: `recipes-kernel/linux/linux-lmp-fslc-imx/imx8mm-jaguar-dt510/`.
Target: rebase onto `linux-fslc` 6.12 (`_kernel-work/linux-fslc`, blobless clone).

**CARRY (forward-port onto 6.12):**
- BQ257xx charger stack: `0010`–`0024` (MFD + power-supply + regulator + dt-bindings;
  wholly upstream at 6.18 → cleanest to cherry-pick from mainline onto 6.12).
- DT510 ASoC deltas: `0026` (tas6424 tannoy control rename), `0028` (fsl-sai sai5 tx-sync).
- pcm6240 (TAA5412 mic): `pcm6240-lmp/0002` (optional-interrupt), `0003`
  (capture-startup pre-power-up), `0004` (asi-tx pasi0 on capture). Base pcm6240 is
  in 6.12 already.
- TAC5x1x (TAC5301 cabin loop) Lore "263" series: `tac5x1x-lmp/patches/01..07`
  (lore-263-2..8) + `07a/07b` (codecs Makefile wiring — re-verify vs 6.12 tree).
  `10-dt510-tac5301-analog-dt-defaults` (DT510-local).

**DROP (already upstream in 6.12, or 6.6-only shims):**
- `0025` bq257xx usb_types (explicit *"kernel-6.6"* shim).
- `pcm6240-lmp/0001` (import-from-mainline-v6.10 — pcm6240 already in 6.12).
- `tac5x1x-lmp/patches/08` (linux-6.6-fslc-compat), `09` (pinctrl-gpiochip-6.6-compat).
- Debug-only: `0001/0003/0004/0005` (asoc-simple-card / fsl-sai / asoc-pcm debug logging).

**INVESTIGATE:** `0002-asoc-fsl-dai-nxp-patches` (may be NXP-vendor-only; confirm need vs 6.12).

**cfg fragments** (verify `CONFIG_*` symbol names vs 6.12): `bq25792-charger.cfg`,
`bq257xx-mfd-kconfig.cfg`, `ksz9896-*.cfg`, `tas6424-audio-codec.cfg`,
`tas2562-audio-codec.cfg`, `pcm6240-audio-codec.cfg`, `cp2108-usb-serial.cfg`,
`mcp251xfd-can.cfg`, `pmic-pca9450.cfg`, `rdc-driver.cfg`, `usb-audio-gadget.cfg`,
`video-disable.cfg`, `wifi-power-management.cfg`, `tac5x1x-lmp/tac5x1x-lmp.cfg`.

Net: ~29 patches to carry, ~6 to drop. BQ257xx first (self-contained, fully upstream).

## Staged plan & status

1. [x] Branch `experiment/dt510-mainline-kernel` off `main`.
2. [x] Kernel provider → `linux-fslc` 6.12 for DT510 (`imx8mm-jaguar-dt510.conf`).
3. [x] `recipes-kernel/linux/linux-fslc_%.bbappend` scaffold created.
4. [x] **DT rebase (source-level).** Audited full DTS vs mainline base; applied the
   3 of-graph/label fixes (ir-receiver, DSI/HDMI keep-graph, MIPI-CSI). Now stays
   on `#include "freescale/imx8mm-evkb.dts"` (exists in mainline) — no re-include
   needed. **CI-verify only.**
5. [x] **DTB build wiring — CONFIRMED, no change needed.** Foundries CI builds the
   DT510 DTB via the `lmp-device-tree` recipe (the `.dts` in
   `recipes-bsp/device-tree/lmp-device-tree/`), *not* the kernel's
   `KERNEL_DEVICETREE` (which the conf itself flags as local-dev-only). That recipe
   `inherit devicetree`; `devicetree.bbclass` sets `KERNEL_INCLUDE` to
   `${STAGING_KERNEL_DIR}/arch/${ARCH}/boot/dts[...]` and adds
   `do_compile depends += virtual/kernel:do_configure`. On this branch
   `virtual/kernel = linux-fslc` (6.12), so the DTS is preprocessed/compiled against
   the **6.12** `freescale/imx8mm-evkb.dts` + `imx8mm.dtsi` + dt-bindings — exactly
   the base the rebase fixes target. The local DD headers (`imx8mm-sw_pad_ctl*.h`)
   ship via the existing `lmp-device-tree.bbappend` `SRC_URI` into `S`, which is on
   the include path. The scaffold `linux-fslc_%.bbappend` DTB-copy stub is only for
   the local `KERNEL_DEVICETREE` path and is inert for CI.
6. [ ] Wire trimmed patch set into `linux-fslc_%.bbappend` (BQ25792 + TAC5x1x
   cherry-picks; drop upstreamed).
7. [ ] Config: port `CONFIG_*` fragments to 6.12 (verify symbol names).
8. [ ] Resolve OOT/stack gaps (IW612 moal/mlan, NXP VPU/AFE) vs 6.12.
9. [ ] Commit + push experiment branch; create vixdt CI branch; monitor build.

## Build note

Do not start `kas`/`bitbake` for this experiment without explicit approval.
Kernel identity check once building:

```bash
bitbake -e linux-fslc | grep '^SRCREV\|^LINUX_VERSION'
```
