#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
# Toggle DT510 DO1–DO4 (gpiochip0 lines 6–9) as *held* push-pull outputs.
# Uses one libgpiod gpioset process with --toggle (do not use repeated short
# gpioset+timeout: each exit releases the line and the pin may not toggle on
# the connector).
#
# Usage: sudo dt510-dio-toggle-outputs.sh [duration_sec] [ms_per_half]
#   default: run until Ctrl+C, 10 ms high / 10 ms low
#   example: sudo dt510-dio-toggle-outputs.sh 120 10   -> 2 minutes, 10 ms half-period

set -e
CHIP=gpiochip0
LINES="6=1 7=1 8=1 9=1"
DUR="${1:-}"
MS="${2:-10}"

if [ "$(id -u)" -ne 0 ]; then
	echo "Run as root: sudo $0" >&2
	exit 1
fi

if ! command -v gpioset >/dev/null 2>&1; then
	echo "gpioset not found (libgpiod-tools)" >&2
	exit 1
fi

# Periods: MS high, MS low, repeat (last non-zero => repeat; see gpioset --help)
TOG="${MS}ms,${MS}ms"

if [ -n "$DUR" ] && [ "$DUR" -gt 0 ] 2>/dev/null; then
	exec timeout "$DUR" gpioset -c "$CHIP" -t "$TOG" --banner -C dt510-dio-hwtest -d push-pull $LINES
else
	exec gpioset -c "$CHIP" -t "$TOG" --banner -C dt510-dio-hwtest -d push-pull $LINES
fi
