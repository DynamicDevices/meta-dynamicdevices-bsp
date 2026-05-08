#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
# Poll DT510 digital inputs DI1–DI4 on gpiochip0 (GPIO1).
#
# Mapping (see imx8mm-jaguar-dt510.dts pinctrl_gpio1_dio_in/out):
#   DI1 = GPIO1_IO0  (offset 0)
#   DI2 = GPIO1_IO1  (offset 1)
#   DI3 = GPIO1_IO4  (offset 4)
#   DI4 = GPIO1_IO5  (offset 5)
#
# Outputs DO1–DO4 use offsets 6–9 (dt510-dio-toggle-outputs.sh); this script
# only reads DI lines and does not claim them.
#
# Usage: sudo dt510-dio-poll-inputs.sh [interval_seconds] [--once]
#   default: poll every 0.5 s until Ctrl+C
#   --once: single sample and exit
#   example: sudo dt510-dio-poll-inputs.sh 1
#            sudo dt510-dio-poll-inputs.sh --once

set -e
CHIP=gpiochip0
LINES="0 1 4 5"

if [ "$(id -u)" -ne 0 ]; then
	echo "Run as root: sudo $0" >&2
	exit 1
fi

if ! command -v gpioget >/dev/null 2>&1; then
	echo "gpioget not found (libgpiod-tools)" >&2
	exit 1
fi

INTERVAL=0.5
ONCE=0
for a in "$@"; do
	case "$a" in
	--once) ONCE=1 ;;
	'') ;;
	*[!0-9.]*) ;;
	*) INTERVAL="$a" ;;
	esac
done

poll_once() {
	# libgpiod v2 defaults to keyword values ("0"=inactive …); --numeric gives 0/1.
	set -- $(gpioget --numeric -c "$CHIP" $LINES)
	v0=${1:-?}
	v1=${2:-?}
	v4=${3:-?}
	v5=${4:-?}
	ts=$(date '+%Y-%m-%d %H:%M:%S')
	printf '%s  DI1(IO0)=%s  DI2(IO1)=%s  DI3(IO4)=%s  DI4(IO5)=%s\n' \
		"$ts" "$v0" "$v1" "$v4" "$v5"
}

printf '# DT510 GPIO inputs (%s lines %s) — values 0/1 = inactive/active (libgpiod --numeric)\n' "$CHIP" "$LINES"
while true; do
	poll_once
	if [ "$ONCE" -eq 1 ]; then
		break
	fi
	sleep "$INTERVAL"
done
