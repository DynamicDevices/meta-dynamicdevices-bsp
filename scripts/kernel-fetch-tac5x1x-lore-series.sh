#!/usr/bin/env bash
# Download TI/Niranjan H Y TAC5x1x v1/8 series from lore (linux-sound) as raw mbox
# patches for backport onto linux-lmp-fslc-imx.
#
# Upstream cover letter: Message-ID 20260312184833.263-1-niranjan.hy@ti.com
# Mirror: https://yhbt.net/lore/linux-sound/
#
# Usage (from meta-dynamicdevices-bsp repo root):
#   ./scripts/kernel-fetch-tac5x1x-lore-series.sh [output-dir]
# Default output-dir: recipes-kernel/linux/linux-lmp-fslc-imx/imx8mm-jaguar-dt510/tac5x1x-lmp/patches
#
# After download: rename/reorder if needed, fix rejects against NXP 6.6 tree, then add
# file://.../tac5x1x-lmp/patches/0001-....patch ... to linux-lmp-fslc-imx_%.bbappend
# under MACHINE_FEATURES tac5x1x-audio (see tac5x1x-lmp.cfg header).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-${ROOT}/recipes-kernel/linux/linux-lmp-fslc-imx/imx8mm-jaguar-dt510/tac5x1x-lmp/patches}"
BASE="https://yhbt.net/lore/linux-sound/20260312184833.263"

mkdir -p "${OUT}"

# 263-1 is cover [0/8]; application patches are 263-2 .. 263-9 ([1/8]..[8/8])
declare -a IDS=(2 3 4 5 6 7 8 9)
declare -a IDX=(01 02 03 04 05 06 07 08)

for i in "${!IDS[@]}"; do
	id="${IDS[$i]}"
	num="${IDX[$i]}"
	url="${BASE}-${id}-niranjan.hy@ti.com/raw"
	dest="${OUT}/${num}-tac5x1x-lore-263-${id}.patch"
	echo "Fetching -> ${dest}"
	curl -fsSL "${url}" -o "${dest}"
done

echo "Done. Next: git am --reject --whitespace=fix ${OUT}/*.patch in a clean linux clone at your NXP tag, resolve rejects, export as bbappend-friendly patches."
