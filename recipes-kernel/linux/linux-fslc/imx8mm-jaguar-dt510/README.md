# `linux-fslc` DT510 kernel files (6.12 mainline experiment)

Files consumed by `recipes-kernel/linux/linux-fslc_%.bbappend` for
`MACHINE = imx8mm-jaguar-dt510` on the community **linux-fslc 6.12 LTS** kernel.

## `patches/` — forward-ported driver stacks (27 patches)

Rebased from the NXP 6.6 queue (`../../linux-lmp-fslc-imx/imx8mm-jaguar-dt510/`)
onto `linux-fslc` **SRCREV `e92f5b7050c7`** (= `linux-fslc_6.12.bb`, 6.12.34), so
they apply with no SRCREV drift. Applied in numeric order (they build on each
other). Generated in `_kernel-work/linux-fslc` (branch `dt510-fslc-6.12-fwdport`).

- `0001`–`0015` — BQ257xx→**BQ25792** charger (MFD + power-supply + regulator + bindings).
- `0016`–`0017` — **pcm6240** capture deltas (TAA5412 mic path); the v6.10 import and
  the "optional interrupt" patch were dropped (already satisfied by 6.12's `of_irq_get`).
- `0018`–`0025` — **TAC5x1x/TAC5301** Lore "263" series (bindings + MFD + pinctrl +
  ASoC codec) + 6.12-style codecs Makefile wiring + DT510 analog defaults.
- `0026`–`0027` — DT510-local ASoC (`tas6424` control rename, `fsl_sai` SAI5 sync-rx).

**Dropped during forward-port** (already upstream in 6.12, or 6.6-only shims): the
`tas2781`/`tas2563` import (6.8), pcm6240 v6.10 import, the `linux-6.6-fslc-compat`
and `pinctrl-gpiochip-6.6-compat` shims, the `bq257xx` usb_types 6.6 fixup, and the
6.6-era `snd-soc-*-objs` Makefile hacks (replaced with the 6.12 `-y :=` form).

## `*.cfg` — config fragments

Merged by kernel-yocto (via `linux-imx.inc`) on top of the in-tree arm64 `defconfig`.
Driver symbols (`MFD_BQ257XX`, `CHARGER_BQ257XX`, `REGULATOR_BQ257XX`, `MFD_TAC5X1X`,
`PINCTRL_TI_TAC5X1X`, `SND_SOC_TAC5X1X`) match what the patches add.

## Device tree

The board DTS (`recipes-bsp/device-tree/lmp-device-tree/imx8mm-jaguar-dt510.dts`) is
rebased onto the mainline `freescale/imx8mm-evk` base (of-graph phandles kept intact;
`ir-receiver` removed by name). The bbappend's `do_configure` installs it into
`freescale/`, rewrites the `#include` prefix, and adds its dtb rule to `freescale/Makefile`.

See `../../../../docs/DT510-MAINLINE-KERNEL-MIGRATION.md`.
