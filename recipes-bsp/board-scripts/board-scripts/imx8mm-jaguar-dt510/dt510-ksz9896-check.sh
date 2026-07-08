#!/bin/bash
#
# DT510 — KSZ9896 gigabit switch health check (DSA over I2C).
#
# The KSZ9896 is a 4-port switch on &i2c3 (Linux i2c-2) at 7-bit address 0x5f,
# with the FEC as the RGMII CPU/conduit port and DSA user ports lan1..lan4.
# A dead or un-reset switch fails silently: the FEC "eth0" conduit can still
# report state UP / LOWER_UP (fixed-link), so a plain link+ping test PASSES on a
# board whose switch never came up. The only reliable evidence the switch chip
# is actually alive is that the driver bound to it over I2C AND DSA enumerated
# lan1..lan4. This helper asserts exactly that so both production-test.sh and the
# bench use one definition of "switch healthy".
#
#   dt510-ksz9896-check.sh             # concise PASS/FAIL, exit 0 = healthy
#   dt510-ksz9896-check.sh --verbose   # also dump i2cdetect + dmesg evidence
#
# dmesg / i2cdetect want root; run under sudo on the bench. Missing dmesg access
# only weakens the -ENXIO check (it can never false-fail on that).
#
set -uo pipefail

VERBOSE=0
case "${1:-}" in
-v | --verbose) VERBOSE=1 ;;
"") ;;
-h | --help)
	echo "Usage: dt510-ksz9896-check.sh [--verbose]"
	exit 0
	;;
*)
	echo "Unknown option: $1" >&2
	exit 2
	;;
esac

LAN_PORTS="lan1 lan2 lan3 lan4"
fail=0
note() { echo "  $*"; }
bad() {
	echo "  FAIL: $*"
	fail=1
}

echo "KSZ9896 switch health check:"

# 1) Driver bound over I2C at 0x5f — definitive "chip ACKed and the ksz driver
#    claimed it". DTS puts switch@5f on &i2c3; Linux sysfs names it '<bus>-005f'.
bus=""
dev="$(ls -d /sys/bus/i2c/devices/*-005f 2>/dev/null | head -1)"
if [ -z "$dev" ]; then
	bad "no I2C device node at address 0x5f (switch not on the bus — check ENET_RST#, power, I2C strap)"
else
	bus="${dev##*/}"
	bus="${bus%%-*}"
	if [ -e "$dev/driver" ]; then
		note "0x5f driver bound: $(basename "$(readlink -f "$dev/driver")") (i2c-$bus)"
	else
		bad "0x5f present but no driver bound (probe failed — expect ksz -ENXIO in dmesg)"
	fi
fi

# 2) DSA must have enumerated all four user ports.
for p in $LAN_PORTS; do
	if [ -e "/sys/class/net/$p" ]; then
		note "$p present"
	else
		bad "$p missing (DSA did not enumerate the switch ports)"
	fi
done

# 3) No KSZ I2C read failure in the kernel log (the classic dead-switch signature).
if dmesg 2>/dev/null | grep -Eiq 'ksz.*(ENXIO|can.t read 16bit reg)'; then
	bad "kernel log shows KSZ I2C read failure (-ENXIO) — switch not responding"
fi

if [ "$VERBOSE" -eq 1 ]; then
	echo "  --- evidence ---"
	if command -v i2cdetect >/dev/null 2>&1 && [ -n "$bus" ]; then
		echo "  i2cdetect -y -r $bus (expect 'UU' at 5f = driver bound):"
		i2cdetect -y -r "$bus" 2>/dev/null | sed 's/^/    /'
	fi
	echo "  ip -br link (switch user ports):"
	ip -br link 2>/dev/null | grep -E '\<lan[1-4]\>' | sed 's/^/    /' || echo "    (none)"
	dmesg 2>/dev/null | grep -Ei 'dsa|ksz' | tail -12 | sed 's/^/    /' || true
fi

if [ "$fail" -eq 0 ]; then
	echo "KSZ9896 PASS: driver bound at 0x5f, lan1-lan4 present, no I2C errors"
	exit 0
fi
echo "KSZ9896 FAIL: switch not healthy (see FAIL lines above)"
exit 1
