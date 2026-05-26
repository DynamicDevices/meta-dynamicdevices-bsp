#!/usr/bin/env bash
# Lint kernel .patch files before commit/push — catches corrupt hunks and do_patch failures.
#
# Usage:
#   ./meta-dynamicdevices-bsp/scripts/kernel-patch-lint.sh [patch ...]
#   ./meta-dynamicdevices-bsp/scripts/kernel-patch-lint.sh --changed   # git changed *.patch in BSP
#
# Optional full apply check (matches Yocto do_patch more closely):
#   export VIXDT_KERNEL_SRC=/path/to/linux-6.6.52+git
#   ./meta-dynamicdevices-bsp/scripts/kernel-patch-lint.sh --changed --dry-run-apply
#
# VIXDT_KERNEL_SRC must be an unpacked tree at the same version/bitbake applies against
# (e.g. after bitbake -c unpack linux-lmp-fslc-imx, or a git checkout of lmp-linux).
set -euo pipefail

BSP_ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
KERNEL_RECIPE_DIR="$BSP_ROOT/recipes-kernel/linux/linux-lmp-fslc-imx"
LINT_PY="$BSP_ROOT/scripts/kernel-patch-lint.py"
DRY_RUN_APPLY=0
MODE=files
PATCHES=()

while [ $# -gt 0 ]; do
	case "$1" in
	--changed) MODE=changed; shift ;;
	--dry-run-apply) DRY_RUN_APPLY=1; shift ;;
	-*) echo "Unknown option: $1" >&2; exit 2 ;;
	*) PATCHES+=("$1"); shift ;;
	esac
done

if [ "$MODE" = changed ]; then
	mapfile -t PATCHES < <(
		git -C "$BSP_ROOT" diff --name-only --diff-filter=ACMR 2>/dev/null
		git -C "$BSP_ROOT" diff --cached --name-only --diff-filter=ACMR 2>/dev/null
	) || true
	uniq_patches=()
	for f in "${PATCHES[@]}"; do
		case "$f" in
		*.patch) uniq_patches+=("$BSP_ROOT/$f") ;;
		esac
	done
	mapfile -t PATCHES < <(printf '%s\n' "${uniq_patches[@]}" | sort -u)
fi

if [ ${#PATCHES[@]} -eq 0 ]; then
	echo "kernel-patch-lint: no patches to check."
	exit 0
fi

fail=0

echo "kernel-patch-lint: ${#PATCHES[@]} patch(es)"

for p in "${PATCHES[@]}"; do
	if [ ! -f "$p" ]; then
		echo "ERROR: missing $p" >&2
		fail=1
		continue
	fi
	echo "==> structure: $p"
	if ! python3 "$LINT_PY" "$p"; then
		fail=1
	fi
done

if [ "$DRY_RUN_APPLY" -eq 1 ]; then
	if [ -z "${VIXDT_KERNEL_SRC:-}" ] || [ ! -d "$VIXDT_KERNEL_SRC" ]; then
		echo "ERROR: --dry-run-apply requires VIXDT_KERNEL_SRC pointing at unpacked kernel tree" >&2
		exit 1
	fi
	echo "==> dry-run apply (dt510 stack) against $VIXDT_KERNEL_SRC"
	if ! "$BSP_ROOT/scripts/kernel-patch-dt510-dry-run.sh" "$VIXDT_KERNEL_SRC"; then
		fail=1
	fi
fi

if [ "$fail" -ne 0 ]; then
	echo "kernel-patch-lint: FAILED" >&2
	exit 1
fi
echo "kernel-patch-lint: OK"
exit 0
