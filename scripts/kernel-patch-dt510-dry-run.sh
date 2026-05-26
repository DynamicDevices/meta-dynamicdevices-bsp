#!/usr/bin/env bash
# Apply imx8mm-jaguar-dt510 kernel patches in filename order with patch --dry-run -p1.
# Requires unpacked kernel source (same tree bitbake uses after base patches).
set -euo pipefail

if [ $# -lt 1 ]; then
	echo "Usage: $0 /path/to/kernel-source" >&2
	exit 2
fi

KERNEL_SRC=$1
BSP_ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
DT510_DIR="$BSP_ROOT/recipes-kernel/linux/linux-lmp-fslc-imx/imx8mm-jaguar-dt510"

if [ ! -d "$KERNEL_SRC" ]; then
	echo "ERROR: kernel source not found: $KERNEL_SRC" >&2
	exit 1
fi

work=$(mktemp -d)
cleanup() { rm -rf "$work"; }
trap cleanup EXIT

cp -a "$KERNEL_SRC/." "$work/"
cd "$work"

# Top-level dt510 patches (numeric), then pcm6240-lmp/, then tac5x1x-lmp/patches/
mapfile -t PATCHES < <(
	find "$DT510_DIR" -name '*.patch' -type f | LC_ALL=C sort
)

echo "kernel-patch-dt510-dry-run: ${#PATCHES[@]} patches in $work"

n=0
for p in "${PATCHES[@]}"; do
	n=$((n + 1))
	echo "==> ($n/${#PATCHES[@]}) $(basename "$p")"
	if ! patch -p1 --dry-run --forward --batch --silent <"$p"; then
		echo "ERROR: patch --dry-run failed: $p" >&2
		exit 1
	fi
	# Apply for real so later patches see cumulative state (still in temp tree)
	patch -p1 --forward --batch --silent <"$p"
done

echo "kernel-patch-dt510-dry-run: OK"
