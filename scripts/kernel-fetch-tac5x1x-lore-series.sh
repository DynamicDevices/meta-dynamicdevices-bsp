#!/usr/bin/env bash
# Download TI/Niranjan H Y TAC5x1x v1/8 series (linux-sound) as raw mbox patches.
#
# Upstream cover letter: Message-ID 20260312184833.263-1-niranjan.hy@ti.com
# Primary mirror (raw mbox): https://yhbt.net/lore/linux-sound/
#
# Usage (from meta-dynamicdevices-bsp repo root):
#   ./scripts/kernel-fetch-tac5x1x-lore-series.sh [output-dir]
# Default output-dir: recipes-kernel/linux/linux-lmp-fslc-imx/imx8mm-jaguar-dt510/tac5x1x-lmp/patches
#
# Some mboxes contain invalid Content-Type: charset="yes" (breaks git am).
# Normalized to UTF-8 after download.
#
# Next: ./scripts/kernel-am-tac5x1x-lore-series.sh /path/to/linux

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-${ROOT}/recipes-kernel/linux/linux-lmp-fslc-imx/imx8mm-jaguar-dt510/tac5x1x-lmp/patches}"
BASE="https://yhbt.net/lore/linux-sound/20260312184833.263"

mkdir -p "${OUT}"

normalize_mbox_charset() {
	local f="$1"
	if grep -q 'charset="yes"' "${f}" 2>/dev/null; then
		sed -i 's/charset="yes"/charset="UTF-8"/g' "${f}"
	fi
}

declare -a IDS=(2 3 4 5 6 7 8 9)
declare -a IDX=(01 02 03 04 05 06 07 08)

for i in "${!IDS[@]}"; do
	id="${IDS[$i]}"
	num="${IDX[$i]}"
	url="${BASE}-${id}-niranjan.hy@ti.com/raw"
	dest="${OUT}/${num}-tac5x1x-lore-263-${id}.patch"
	echo "Fetching -> ${dest}"
	curl -fsSL --max-time 300 -A "Mozilla/5.0 (compatible; DynamicDevices-kernel-fetch)" "${url}" -o "${dest}"
	normalize_mbox_charset "${dest}"
	wc -c "${dest}"
done

echo "Done. Next: ./scripts/kernel-am-tac5x1x-lore-series.sh /path/to/linux"
