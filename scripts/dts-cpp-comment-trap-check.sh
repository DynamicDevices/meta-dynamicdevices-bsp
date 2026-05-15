#!/bin/sh
# Fail if DTS/DTSI under this BSP contain "**/" — cpp ends /* */ comments on "*/";
# Markdown bold before a slash often produces "**/" and breaks dtb compilation.
#
# Usage (from workspace root): ./meta-dynamicdevices-bsp/scripts/dts-cpp-comment-trap-check.sh
set -eu
BSP_ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
export BSP_ROOT
if ! command -v rg >/dev/null 2>&1; then
	echo "dts-cpp-comment-trap-check.sh: install ripgrep (rg)" >&2
	exit 2
fi
hits=$(rg --line-number '\*\*/' \
	--glob '*.dts' --glob '*.dtsi' \
	"$BSP_ROOT/recipes-bsp/device-tree" \
	"$BSP_ROOT/recipes-kernel/linux" \
	2>/dev/null || true)
if [ -n "${hits:-}" ]; then
	printf '%s\n' "$hits"
	echo >&2 ""
	echo >&2 "dts-cpp-comment-trap-check.sh: Found **/ in DTS comments (breaks cpp /* */ parsing)." >&2
	echo >&2 "Rewrite: drop Markdown ** near slashes or move prose to docs/." >&2
	exit 1
fi
exit 0
