# kas + yocto-lens (vixdt / imx8mm-jaguar-dt510)

vixdt does **not** ship a kas YAML today. Factory builds use Foundries **repo sync** via `lmp-manifest/vixdt.xml`, not kas.

When you add a kas file for local LmP builds, run yocto-lens against the **full checked-out stack** (not just Dynamic Devices layers) to keep orphan-bbappend and layer-dependency noise down.

## Quick scan (Dynamic Devices layers only)

From the vixdt workspace root:

```bash
./scripts/vixdt-yocto-lens-kas.sh --markdown
```

Reports land under `/tmp/yocto-lens-vixdt.*` by default.

This scans only:

- `meta-dynamicdevices-bsp`
- `meta-dynamicdevices-distro`
- `meta-subscriber-overrides`

Expect **orphan-bbappend** and **layer-missing-dependency** HIGH findings on a DD-only scan — upstream recipes and layers are not visible.

## Full factory stack scan (repo sync)

Use this before treating HIGH findings as real. Matches what Foundries CI sees for layer resolution.

### 1. Check out the factory manifest

Use a directory **outside** the vixdt sibling repos (repo sync is large):

```bash
mkdir -p ~/lmp-vixdt && cd ~/lmp-vixdt

repo init -u https://source.foundries.io/factories/vixdt/lmp-manifest \
  -b main-imx8mm-jaguar-dt510 \
  -m vixdt.xml

repo sync -j$(nproc)
```

Foundries auth may be required for `source.foundries.io` remotes.

Dynamic Devices layers land under `layers/meta-dynamicdevices/meta-dynamicdevices-bsp` and `.../meta-dynamicdevices-distro`; subscriber overrides at `layers/meta-subscriber-overrides` (paths from `lmp-manifest/vixdt.xml`).

### 2. Generate `bblayers.conf`

From the repo-sync root:

```bash
MACHINE=imx8mm-jaguar-dt510 source setup-environment build-imx8mm
```

This creates `build-imx8mm/conf/bblayers.conf` with the full LmP layer list.

### 3. Run yocto-lens on all layers

From the **vixdt** workspace (where `scripts/vixdt-yocto-lens-kas.sh` lives):

```bash
./scripts/vixdt-yocto-lens-kas.sh \
  --from-bblayers ~/lmp-vixdt/build-imx8mm/conf/bblayers.conf \
  --markdown
```

Or, if you use kas and already have `build/conf/bblayers.conf`:

```bash
export KAS_WORK_DIR=~/path/to/kas-build-dir
kas checkout your-imx8mm-jaguar-dt510.yml
./scripts/vixdt-yocto-lens-kas.sh --from-kas --markdown
```

Output defaults: `/tmp/yocto-lens-vixdt.json`, `.sarif`, `-report.md`, `-report.txt`. Override with `VIXDT_YOCTO_LENS_JSON`, `--json`, etc. (see script `--help`).

## Interpreting common findings

### `static/bbappend-modifies-source-or-install` (MEDIUM)

**Expected** for BSP, distro, and subscriber layers. Appends that set `SRC_URI`, `FILESEXTRAPATHS`, `do_install`, or `SYSTEMD_*` are normal product customization — review that the change is intentional, not a signal to delete the append.

### `static/host-absolute-path` on `/home/...` or `/var/...`

Often **false positives**: target rootfs paths in `do_install`, `FILES`, `EXTRA_USERS_PARAMS`, or `DESCRIPTION` (e.g. `/home/root/.profile`, `/var/lib/vix/...`). Real host leaks look like `/home/<developer>/...` or hard-coded build-machine paths outside `${D}`, `${WORKDIR}`, `${THISDIR}`.

### `static/license-missing` / `license-missing-lic-files-chksum`

Check **`require` / `include` `.inc` files** (e.g. `nxp-wlan-sdk_git.inc` holds `LICENSE`). Multi-line `LIC_FILES_CHKSUM` continuations may not be parsed — confirm in the `.bb` / `.inc` before changing recipes.

### `static/orphan-bbappend` (HIGH)

Usually disappears on a **full-stack** scan. On DD-only scans, treat as inconclusive until `--from-bblayers` is used.

## CI / gate behaviour

- **Default:** report-only (`exit 0`). yocto-lens itself does not fail on HIGH findings.
- **Strict gate:** `VIXDT_YOCTO_LENS_FAIL_ON_HIGH=1 ./scripts/vixdt-yocto-lens-kas.sh --from-bblayers …`
- Recommended: stay report-only until the actionable HIGH baseline is understood on a full-stack scan; then enable `--fail-on-high` in CI.

## Binary

Install `yocto-lens` locally (not vendored in this repo). Default path: `/tmp/yocto-lens`. Override with `YOCTO_LENS=/path/to/yocto-lens`.

## Pre-push (default)

`./scripts/vixdt-pre-push-checks.sh` runs yocto-lens **report-only** when BSP, distro, or subscriber recipe/layer metadata changed (`*.bb`, `*.bbappend`, `*.inc`, `conf/layer.conf`). Disable with `VIXDT_YOCTO_LENS=0`. Still DD-layers-only unless you point at a full `bblayers.conf`.
