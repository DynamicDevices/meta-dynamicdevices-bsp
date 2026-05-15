#!/bin/bash
# DT510 — read-only dump of Silicon Labs CP2108 (U13) USB customization space via cp210x-program.
#
# The in-kernel cp210x driver attaches four interfaces per CP2108; PyUSB/libusb cannot reliably
# claim configuration while those drivers are bound. This script temporarily unbinds all
# 1-<port>:1.{0..3} interfaces from cp210x, runs cp210x-program --read-cp210x, then rebinds.
#
# Requires root (sudo). Ships when MACHINE_FEATURES includes cp2108-usb-serial (see board-scripts.bb).
#
# Limitation: CP2108 often STALLs the legacy CP2102-style EEPROM control read (wValue 0x3709, 1024 B)
# used by upstream cp210x-program — reads may fail with errno 32 (EPIPE). If so, use Simplicity /
# Silicon Labs programming utilities and export NVM from there (docs: DT510-HARDWARE-AUDIT-CHECKLIST CP2108 §).
#
# Usage:
#   sudo dt510-cp2108-read-config.sh
#   sudo dt510-cp2108-read-config.sh -o /mnt/usb/cp2108.hex   # same as --hex PATH
#   sudo dt510-cp2108-read-config.sh --hex /tmp/cp2108.hex    # default hex path: /tmp/cp2108-read.hex
#   sudo dt510-cp2108-read-config.sh --ini /tmp/cp2108.ini
#   sudo dt510-cp2108-read-config.sh --ini /tmp/cp2108.ini --hex /tmp/cp2108.hex
#   sudo dt510-cp2108-read-config.sh --match 001/004 --ini -
#
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

usage_err() {
	echo "Usage: $0 [--match BUS/DEV] [-o|--output PATH | --hex PATH] [--ini PATH]" >&2
	echo "  (omit --hex/--output/--ini: write Intel HEX only to /tmp/cp2108-read.hex)" >&2
	echo "  -o PATH, --output PATH   Intel HEX destination (same as --hex)" >&2
	echo "  --match 001/004          libusb match: 3-digit bus and device (default: auto-detect CP2108 10c4:ea71)" >&2
	echo "  --ini PATH               decoded field values (\`-' = stdout)" >&2
	echo "  --hex PATH               Intel HEX image (\`-' = stdout)" >&2
	exit 1
}

usage_help() {
	echo "Usage: $0 [--match BUS/DEV] [-o|--output PATH | --hex PATH] [--ini PATH]"
	echo "  Default: hex only -> /tmp/cp2108-read.hex"
	echo "  -o PATH, --output PATH   hex file (synonym for --hex)"
	echo "  --match 001/004          libusb match (default: auto-detect 10c4:ea71)"
	echo "  --ini PATH               field dump (\`-' = stdout)"
	echo "  --hex PATH               Intel HEX (\`-' = stdout)"
	exit 0
}

MATCH_ARG=""
INI_OUT=""
HEX_OUT=""

while [ $# -gt 0 ]; do
	case "$1" in
	--match)
		MATCH_ARG="${2:-}"
		shift 2
		;;
	--ini)
		INI_OUT="${2:-}"
		if [ -z "$INI_OUT" ]; then
			echo "ERR: missing path after --ini" >&2
			usage_err
		fi
		shift 2
		;;
	-o | --output)
		HEX_OUT="${2:-}"
		if [ -z "$HEX_OUT" ]; then
			echo "ERR: missing path after $1" >&2
			usage_err
		fi
		shift 2
		;;
	--hex)
		HEX_OUT="${2:-}"
		if [ -z "$HEX_OUT" ]; then
			echo "ERR: missing path after --hex" >&2
			usage_err
		fi
		shift 2
		;;
	-h | --help)
		usage_help
		;;
	*)
		echo "Unknown option: $1" >&2
		usage_err
		;;
	esac
done

# Default output: Intel HEX (cp210x raw image); INI is optional.
DEFAULT_HEX="/tmp/cp2108-read.hex"
if [ -z "$INI_OUT" ] && [ -z "$HEX_OUT" ]; then
	HEX_OUT="$DEFAULT_HEX"
	echo "Note: no --hex/--output/-o/--ini; writing hex to ${HEX_OUT}" >&2
fi

if [ "$(id -u)" -ne 0 ]; then
	echo "ERR: run as root (this script unbinds kernel cp210x). Example: sudo $0 ..." >&2
	exit 1
fi

if ! command -v cp210x-program >/dev/null 2>&1; then
	echo "ERR: cp210x-program not found. Install package cp210x-program (cp2108-usb-serial image)." >&2
	exit 1
fi

UNBOUND=0
CP2108_BASE=""

cleanup() {
	if [ "$UNBOUND" = 1 ] && [ -n "$CP2108_BASE" ]; then
		for i in 0 1 2 3; do
			echo "${CP2108_BASE}:1.${i}" >/sys/bus/usb/drivers/cp210x/bind 2>/dev/null || true
		done
	fi
}
trap cleanup EXIT

if [ -n "$MATCH_ARG" ]; then
	# User supplied bus/address; still need sysfs base for unbind (derive from dev path).
	found=0
	for devpath in /sys/bus/usb/devices/*; do
		[ -f "${devpath}/busnum" ] || continue
		base=$(basename "$devpath")
		[[ "$base" == *:* ]] && continue
		bn=$(printf '%03d' "$(tr -d ' \n' <"${devpath}/busnum")")
		dn=$(printf '%d' "$(tr -d ' \n' <"${devpath}/devnum")")
		dn3=$(printf '%03d' "$dn")
		if [ "${bn}/${dn3}" = "$MATCH_ARG" ] || [ "${bn}/${dn}" = "$MATCH_ARG" ]; then
			v=$(tr -d ' \n' <"${devpath}/idVendor" 2>/dev/null || true)
			p=$(tr -d ' \n' <"${devpath}/idProduct" 2>/dev/null || true)
			if [ "$v" = "10c4" ] && [ "$p" = "ea71" ]; then
				CP2108_BASE="$base"
				found=1
				break
			fi
		fi
	done
	if [ "$found" -ne 1 ]; then
		echo "ERR: no sysfs device for --match ${MATCH_ARG} with id 10c4:ea71 (CP2108)" >&2
		exit 1
	fi
else
	for devpath in /sys/bus/usb/devices/*; do
		[ -f "${devpath}/idVendor" ] || continue
		base=$(basename "$devpath")
		[[ "$base" == *:* ]] && continue
		v=$(tr -d ' \n' <"${devpath}/idVendor")
		p=$(tr -d ' \n' <"${devpath}/idProduct")
		if [ "$v" = "10c4" ] && [ "$p" = "ea71" ]; then
			CP2108_BASE="$base"
			break
		fi
	done
	if [ -z "$CP2108_BASE" ]; then
		echo "ERR: no CP2108 (USB id 10c4:ea71) found under /sys/bus/usb/devices" >&2
		exit 1
	fi
fi

SYS_DEV="/sys/bus/usb/devices/${CP2108_BASE}"
BUSNUM=$(printf '%03d' "$(tr -d ' \n' <"${SYS_DEV}/busnum")")
DEVNUM=$(printf '%03d' "$(tr -d ' \n' <"${SYS_DEV}/devnum")")
MATCH="${BUSNUM}/${DEVNUM}"

echo "=== dt510-cp2108-read-config ($(date -Iseconds)) ==="
echo "Sysfs: ${CP2108_BASE}  match: -m ${MATCH}"
outparts=()
[ -n "$HEX_OUT" ] && outparts+=("hex:${HEX_OUT}")
[ -n "$INI_OUT" ] && outparts+=("ini:${INI_OUT}")
echo "Output: ${outparts[*]}"

for i in 0 1 2 3; do
	if [ ! -e "/sys/bus/usb/devices/${CP2108_BASE}:1.${i}" ]; then
		echo "ERR: missing interface ${CP2108_BASE}:1.${i} (not a quad CP2108 layout?)" >&2
		exit 1
	fi
	echo "${CP2108_BASE}:1.${i}" >/sys/bus/usb/drivers/cp210x/unbind
done
UNBOUND=1

CMD=(cp210x-program --read-cp210x -m "${MATCH}")
if [ -n "$HEX_OUT" ]; then
	CMD+=(-f "$HEX_OUT")
fi
if [ -n "$INI_OUT" ]; then
	CMD+=(-i "$INI_OUT")
fi

set +e
"${CMD[@]}"
RC=$?
set -e

if [ "$RC" -ne 0 ]; then
	echo "WARN: cp210x-program exited $RC (often EPIPE/STALL on CP2108 EEPROM read)." >&2
	echo "WARN: Prefer Silicon Labs NVM export / AN721 toolchain for authoritative CP2108 images." >&2
fi

exit "$RC"
