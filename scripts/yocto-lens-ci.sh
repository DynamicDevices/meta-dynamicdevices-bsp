#!/usr/bin/env bash
# Run yocto-lens static scan for Dynamic Devices public layers (CI / local).
#
# Defaults: meta-dynamicdevices-bsp (this repo) + sibling meta-dynamicdevices-distro.
# Does not include meta-subscriber-overrides (private Foundries repo).
# No duplicate-path filtering needed here (single checkout per layer in CI).
#
# Examples:
#   ./scripts/yocto-lens-ci.sh
#   FAIL_ON_HIGH=1 ./scripts/yocto-lens-ci.sh
#   YOCTO_LENS_VERSION=v0.1.0 OUTPUT_DIR=./yocto-lens-out ./scripts/yocto-lens-ci.sh
set -euo pipefail

BSP_ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
DISTRO_ROOT=${DISTRO_ROOT:-"$(CDPATH= cd -- "$BSP_ROOT/.." && pwd)/meta-dynamicdevices-distro"}

YOCTO_LENS_VERSION=${YOCTO_LENS_VERSION:-v0.1.0}
YOCTO_LENS=${YOCTO_LENS:-/tmp/yocto-lens}
OUTPUT_DIR=${OUTPUT_DIR:-/tmp/yocto-lens-ci}
JSON_OUT=${JSON_OUT:-$OUTPUT_DIR/yocto-lens-dd-layers.json}
SARIF_OUT=${SARIF_OUT:-$OUTPUT_DIR/yocto-lens-dd-layers.sarif}
MODE=${YOCTO_LENS_MODE:-static}
FAIL_ON_HIGH=${FAIL_ON_HIGH:-0}

download_yocto_lens() {
	if [ -x "$YOCTO_LENS" ]; then
		return 0
	fi
	local asset="yocto-lens-linux-amd64.tar.gz"
	local url="https://github.com/prashantdivate/yocto-lens/releases/download/${YOCTO_LENS_VERSION}/${asset}"
	local tmp
	tmp=$(mktemp -d)
	trap 'rm -rf "$tmp"' RETURN
	echo "==> Downloading yocto-lens ${YOCTO_LENS_VERSION} (${url})"
	curl -fsSL "$url" -o "$tmp/${asset}"
	tar -xzf "$tmp/${asset}" -C "$tmp"
	install -m 0755 "$tmp/yocto-lens" "$YOCTO_LENS"
}

collect_layers() {
	local -a layers=()
	if [ -d "$BSP_ROOT/conf" ]; then
		layers+=("$BSP_ROOT")
	fi
	if [ -d "$DISTRO_ROOT/conf" ]; then
		layers+=("$DISTRO_ROOT")
	fi
	if [ ${#layers[@]} -eq 0 ]; then
		echo "No layer paths with conf/ found (BSP=$BSP_ROOT DISTRO=$DISTRO_ROOT)" >&2
		exit 2
	fi
	printf '%s\n' "${layers[@]}"
}

download_yocto_lens
mkdir -p "$OUTPUT_DIR"

mapfile -t LAYER_PATHS < <(collect_layers)

echo "==> yocto-lens CI scan (${#LAYER_PATHS[@]} layers, mode=$MODE)"
for p in "${LAYER_PATHS[@]}"; do
	echo "    $p"
done

"$YOCTO_LENS" \
	--no-tui \
	-mode "$MODE" \
	-json "$JSON_OUT" \
	-sarif "$SARIF_OUT" \
	"${LAYER_PATHS[@]}"

echo ""
echo "JSON:  $JSON_OUT"
echo "SARIF: $SARIF_OUT"

if [ "$FAIL_ON_HIGH" = "1" ]; then
	high_count=$(python3 - "$JSON_OUT" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as fp:
    data = json.load(fp)
print(sum(1 for f in data.get("findings", []) if f.get("severity") == "HIGH"))
PY
)
	echo "HIGH findings: $high_count"
	if [ "$high_count" -gt 0 ]; then
		echo "yocto-lens-ci: FAILED (FAIL_ON_HIGH=1)" >&2
		exit 1
	fi
fi

echo "yocto-lens-ci: OK"
