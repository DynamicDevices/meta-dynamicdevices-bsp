#!/usr/bin/env bash
# Download TI/Niranjan H Y TAC5x1x v1/8 series (linux-sound) as raw mbox patches.
#
# Upstream cover letter: Message-ID 20260312184833.263-1-niranjan.hy@ti.com
# Primary mirror (raw mbox): https://yhbt.net/lore/linux-sound/
#
# Many users stall at patch 6+ (file 06 = lore 263-7 = [6/8]): yhbt can time out
# mid-series. This script retries each URL, skips already-valid mboxes (resume),
# and validates that the file looks like mbox (starts with "From "), not HTML.
#
# Usage (from meta-dynamicdevices-bsp repo root):
#   ./scripts/kernel-fetch-tac5x1x-lore-series.sh [output-dir]
# Default output-dir: recipes-kernel/linux/linux-lmp-fslc-imx/imx8mm-jaguar-dt510/tac5x1x-lmp/patches
#
# Optional env:
#   TAC5X1X_LORE_BASE  override URL prefix (default .../20260312184833.263)
#   TAC5X1X_FETCH_RETRIES  per-patch attempts (default 5)
#
# Some mboxes contain invalid Content-Type: charset="yes" (breaks git am).
# Normalized to UTF-8 after download.
#
# Next: ./scripts/kernel-am-tac5x1x-lore-series.sh /path/to/linux

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-${ROOT}/recipes-kernel/linux/linux-lmp-fslc-imx/imx8mm-jaguar-dt510/tac5x1x-lmp/patches}"
BASE="${TAC5X1X_LORE_BASE:-https://yhbt.net/lore/linux-sound/20260312184833.263}"
RETRIES="${TAC5X1X_FETCH_RETRIES:-5}"

mkdir -p "${OUT}"

normalize_mbox_charset() {
	local f="$1"
	if grep -q 'charset="yes"' "${f}" 2>/dev/null; then
		sed -i 's/charset="yes"/charset="UTF-8"/g' "${f}"
	fi
}

is_valid_mbox() {
	local f="$1"
	[[ -s "$f" ]] || return 1
	head -1 "$f" | grep -q '^From ' || return 1
	if grep -qi '<!doctype html' "$f" 2>/dev/null; then
		return 1
	fi
	return 0
}

fetch_one() {
	local id="$1" dest="$2" url="${BASE}-${id}-niranjan.hy@ti.com/raw"
	local attempt tmp
	tmp="${dest}.part"
	for ((attempt = 1; attempt <= RETRIES; attempt++)); do
		echo "  try ${attempt}/${RETRIES} ${url}"
		rm -f "$tmp"
		if curl -fsSL --max-time 300 \
			-A "Mozilla/5.0 (compatible; DynamicDevices-kernel-fetch)" \
			"${url}" -o "$tmp" 2>/dev/null && is_valid_mbox "$tmp"; then
			mv "$tmp" "$dest"
			normalize_mbox_charset "$dest"
			return 0
		fi
		rm -f "$tmp"
		local wait=$((5 * attempt))
		echo "  failed; sleep ${wait}s"
		sleep "$wait"
	done
	echo "ERROR: could not fetch valid mbox after ${RETRIES} tries: ${url}" >&2
	return 1
}

declare -a IDS=(2 3 4 5 6 7 8 9)
declare -a IDX=(01 02 03 04 05 06 07 08)

for i in "${!IDS[@]}"; do
	id="${IDS[$i]}"
	num="${IDX[$i]}"
	dest="${OUT}/${num}-tac5x1x-lore-263-${id}.patch"
	if is_valid_mbox "$dest"; then
		echo "Skip (already valid): ${dest}"
		normalize_mbox_charset "$dest"
		wc -c "${dest}"
		continue
	fi
	echo "Fetching -> ${dest}"
	fetch_one "$id" "$dest"
	wc -c "${dest}"
done

echo "Done. Next: ./scripts/kernel-am-tac5x1x-lore-series.sh /path/to/linux"
