# AGENTS.md

## Cursor Cloud specific instructions

### What this repo is
`meta-dynamicdevices-bsp` is a **Yocto / OpenEmbedded BSP meta-layer** (BitBake recipes, machine configs, device trees, kernel patches). It is **not** an application — there are **no servers, daemons, databases, or ports** to run. There is no `package.json`/`Makefile`/`requirements.txt` at the repo root. The only "runnable" things are the lint/scan scripts in `scripts/`, which are the repo's CI.

### Toolchain (already present on the VM)
`bash`, `python3`, `git`, `curl`, and `rg` (ripgrep) are pre-installed. No package manager install step is needed. The only fetched dependency is the `yocto-lens` static-analysis binary, which `scripts/yocto-lens-ci.sh` auto-downloads to `/tmp/yocto-lens` on demand (network required).

### The real CI check: yocto-lens static scan
This is the primary "build/test" of the repo (see `.github/workflows/yocto-lens.yml`). It scans this BSP layer **plus** the sibling `meta-dynamicdevices-distro` layer.

```bash
DISTRO_ROOT="$HOME/meta-dynamicdevices-distro" ./scripts/yocto-lens-ci.sh
```

Gotchas:
- The script's default `DISTRO_ROOT` is `../meta-dynamicdevices-distro`, but `/workspace`'s parent (`/`) is **not writable**. The update script clones the distro layer to `$HOME/meta-dynamicdevices-distro` instead, so always pass `DISTRO_ROOT="$HOME/meta-dynamicdevices-distro"`. If that clone is missing (e.g. update script was skipped/offline), the scan still runs BSP-only.
- Default mode is **report-only**: it prints findings and exits `0` (`yocto-lens-ci: OK`) even with HIGH findings. HIGH findings (orphan-bbappend, layer-missing-dependency) are **expected noise** on a Dynamic-Devices-only scan because upstream LmP layers aren't present — see `docs/kas/README.md`. Use `FAIL_ON_HIGH=1` only for a strict gate.

### Other lint scripts
- `./scripts/dts-cpp-comment-trap-check.sh` — flags `**/` comment traps in DTS/DTSI (needs `rg`).
- `./scripts/kernel-patch-lint.sh --changed` — lints `.patch` files you changed. Intended for *changed* patches only; running it across all committed patches surfaces false positives on git metadata lines (`new file mode 100644`, format-patch version trailers like `2.43.0`).

### Full firmware builds
Building actual board images requires a multi-gigabyte external Foundries.io LmP stack via `repo sync` (and possibly Foundries auth), plus physical i.MX hardware to flash. This is impractical in the cloud VM — see `docs/kas/README.md`. Day-to-day verification here is the lint/scan scripts above.
