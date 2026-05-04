#!/usr/bin/env bash
# Apply fetched TAC5x1x lore mboxes (01..08) to a Linux git tree in order.
#
# Usage:
#   ./scripts/kernel-am-tac5x1x-lore-series.sh /path/to/linux [patch-dir]
#
# patch-dir default: recipes-kernel/linux/linux-lmp-fslc-imx/imx8mm-jaguar-dt510/tac5x1x-lmp/patches
# (relative to meta-dynamicdevices-bsp root when second arg omitted).
#
# Expect a clean working tree. On failure: cd linux && git am --abort

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LINUX="${1:?usage: $0 /path/to/linux [patch-dir]}"
PATCHDIR="${2:-${ROOT}/recipes-kernel/linux/linux-lmp-fslc-imx/imx8mm-jaguar-dt510/tac5x1x-lmp/patches}"

cd "${LINUX}"
shopt -nullglob
files=( "${PATCHDIR}"/0[1-8]-tac5x1x-lore-263-*.patch )
if [[ ${#files[@]} -eq 0 ]]; then
	echo "No patches matching 0[1-8]-tac5x1x-lore-263-*.patch in ${PATCHDIR}" >&2
	exit 1
fi
IFS=$'\n' sorted=( $(printf '%s\n' "${files[@]}" | sort) )
for p in "${sorted[@]}"; do
	echo "==== git am $(basename "$p") ===="
	git am --whitespace=nowarn "${p}"
done
echo "All applied. Create BSP commits with: git format-patch -1 <base> or export diffs."
