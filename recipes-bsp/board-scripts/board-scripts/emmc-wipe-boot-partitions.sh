#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Unlock eMMC hardware boot partitions (boot0/boot1) and fill them with zeros.
# Intended for lab / manufacturing recovery when combined with reflashing (e.g. uuu).
#
# WARNING: After this, the SoC will only still boot if the Boot ROM loads firmware
# from the eMMC *user area* (or another configured source). Wiping boot partitions
# alone may be insufficient to force Serial Download Mode on all fuse/strap configs.
#
# Usage:
#   sudo ./emmc-wipe-boot-partitions.sh --yes
#   sudo EMMC_DISK=mmcblk2 ./emmc-wipe-boot-partitions.sh --yes
#
set -euo pipefail

EMMC_DISK="${EMMC_DISK:-mmcblk2}"
YES=0

usage() {
	echo "Usage: sudo $0 --yes"
	echo ""
	echo "  Unlocks ${EMMC_DISK}boot0 and ${EMMC_DISK}boot1 (clears force_ro) and"
	echo "  overwrites each partition with zeros (full size from sysfs)."
	echo ""
	echo "Environment:"
	echo "  EMMC_DISK   MMC block name without /dev/ (default: mmcblk2)"
	echo ""
	echo "Options:"
	echo "  --yes       Required; confirms you accept brick / recovery risk"
	echo "  -h, --help  This help"
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--yes) YES=1 ;;
		-h|--help) usage; exit 0 ;;
		*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
	esac
	shift
done

if [[ "$(id -u)" -ne 0 ]]; then
	echo "Run as root (e.g. sudo $0 --yes)" >&2
	exit 1
fi

if [[ "$YES" -ne 1 ]]; then
	echo "Refusing to run without --yes (destructive)." >&2
	usage >&2
	exit 1
fi

BOOT0="/dev/${EMMC_DISK}boot0"
BOOT1="/dev/${EMMC_DISK}boot1"
SYS0="/sys/class/block/${EMMC_DISK}boot0"
SYS1="/sys/class/block/${EMMC_DISK}boot1"

for dev in "$BOOT0" "$BOOT1"; do
	if [[ ! -b "$dev" ]]; then
		echo "Missing block device: $dev" >&2
		exit 1
	fi
done

for part in 0 1; do
	sys="/sys/class/block/${EMMC_DISK}boot${part}"
	if [[ ! -r "${sys}/force_ro" ]]; then
		echo "Missing ${sys}/force_ro" >&2
		exit 1
	fi
done

echo "Target boot partitions:"
echo "  $BOOT0  sectors=$(cat "${SYS0}/size")  ro=$(cat "${SYS0}/force_ro")"
echo "  $BOOT1  sectors=$(cat "${SYS1}/size")  ro=$(cat "${SYS1}/force_ro")"
echo ""

unlock_ro() {
	local n=$1
	local sys="/sys/class/block/${EMMC_DISK}boot${n}"
	if [[ "$(cat "${sys}/force_ro")" != "0" ]]; then
		echo 0 >"${sys}/force_ro"
	fi
	if [[ "$(cat "${sys}/force_ro")" != "0" ]]; then
		echo "Failed to clear force_ro on ${EMMC_DISK}boot${n}" >&2
		exit 1
	fi
	echo "Unlocked ${EMMC_DISK}boot${n} (force_ro=0)"
}

wipe_dev() {
	local dev=$1
	local sectors
	sectors="$(cat "/sys/class/block/$(basename "$dev")/size")"
	if [[ -z "$sectors" || "$sectors" -eq 0 ]]; then
		echo "Bad sector count for $dev" >&2
		exit 1
	fi
	echo "Wiping $dev ($sectors × 512 bytes) ..."
	# No status=progress — BusyBox dd on minimal images may not support it.
	if dd if=/dev/zero of="$dev" bs=512 count="$sectors" conv=fsync; then
		echo "Done $dev"
	else
		echo "dd failed on $dev" >&2
		exit 1
	fi
}

unlock_ro 0
unlock_ro 1

wipe_dev "$BOOT0"
wipe_dev "$BOOT1"

sync
echo ""
echo "Boot partitions wiped. Power-cycle with your recovery host (uuu / mfgtool) ready if needed."
