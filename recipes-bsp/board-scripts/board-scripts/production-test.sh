#!/bin/bash
# Dispatch to machine-specific production test (imx8mm-jaguar-dt510 / imx8mm-jaguar-sentai).
set -euo pipefail

BOARD_SCRIPTS_SHARE="${BOARD_SCRIPTS_SHARE:-/usr/share/board-scripts}"

usage() {
	cat <<EOF
Usage: sudo production-test.sh [OPTIONS]

Runs the manufacturing production test for this board type.

Options:
  --ignore-container-errors  Ignore errors stopping application containers (debug)
  -h, --help                 Show this help
EOF
}

machine_script() {
	local id="" script=""
	if [ -r /proc/device-tree/compatible ]; then
		id=$(tr '\0' '\n' </proc/device-tree/compatible | head -1)
	fi
	case "$id" in
	*imx8mm-jaguar-dt510*)
		script="${BOARD_SCRIPTS_SHARE}/imx8mm-jaguar-dt510/production-test.sh"
		;;
	*imx8mm-jaguar-sentai*)
		script="${BOARD_SCRIPTS_SHARE}/imx8mm-jaguar-sentai/production-test.sh"
		;;
	*)
		echo "production-test.sh: unsupported machine (compatible=${id:-unknown})" >&2
		exit 1
		;;
	esac
	if [ ! -x "$script" ]; then
		echo "production-test.sh: missing executable: $script" >&2
		exit 1
	fi
	printf '%s\n' "$script"
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
	usage
	exit 0
fi

exec "$(machine_script)" "$@"
