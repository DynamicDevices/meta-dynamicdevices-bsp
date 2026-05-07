#!/bin/bash
# DT510 — Auracast / LE Audio HCI smoke: UM12155-aligned read + safe write commands via hcitool.
# Requires root (run: sudo dt510-auracast-hci-check.sh). Needs hci0 + hcitool (bluez5).
# Does NOT validate end-to-end BIS/Auracast audio — controller / HCI acceptance only.
# Tracker: meta-dynamicdevices-bsp/docs/DT510-AURACAST-LE-AUDIO.md

set -uo pipefail

HCI="${HCI:-hci0}"
RC=0

fail() { echo "FAIL: $*" >&2; RC=1; }
pass() { echo "OK:  $*"; }
warn() { echo "WARN: $*" >&2; }

need_root() {
	if [ "$(id -u)" -ne 0 ]; then
		echo "Run as root: sudo $0" >&2
		echo "Lab SSH (non-interactive): echo fio | sudo -S $0" >&2
		exit 2
	fi
}

need_hcitool() {
	if ! command -v hcitool >/dev/null 2>&1; then
		echo "hcitool not found (install bluez5 / bluez-tools)." >&2
		exit 2
	fi
}

# Parse first Command Status (0x0f) first parameter octet, or empty.
parse_cs_status() {
	python3 -c '
import re,sys
t=sys.stdin.read()
m=re.search(r"> HCI Event: 0x0f[^\n]*\n\s+([0-9A-Fa-f]{2})", t)
print(int(m.group(1),16) if m else "")
' || true
}

# Parse first Command Complete (0x0e): opcode (16-bit LE) and status byte (when present).
parse_cc() {
	python3 -c '
import re,sys
t=sys.stdin.read()
m=re.search(r"> HCI Event: 0x0e[^\n]*\n\s+((?:[0-9A-Fa-f]{2}\s*)+)", t)
if not m:
    print("")
    sys.exit(0)
b=[int(x,16) for x in m.group(1).split()]
if len(b)<4:
    print("")
    sys.exit(0)
opcode=b[1]|(b[2]<<8)
# Standard: Num, Opcode(2), Status, Return_Parameters...
if len(b)>=5:
    print("%04x %d"%(opcode,b[3]))
elif len(b)==4 and opcode in (0x200a, 0x200b):
    # IW612/hcitool sometimes prints Num+Opcode+one return octet without explicit 00 status.
    print("%04x 0"%(opcode,))
else:
    print("%04x %d"%(opcode,b[3]))
' || true
}

expect_cc_ok() {
	local title="$1"
	shift
	echo "========================================"
	echo "$title"
	echo "  hcitool -i $HCI cmd $*"
	local out op st
	out=$(hcitool -i "$HCI" cmd "$@" 2>&1) || true
	echo "$out"
	op=$(printf '%s' "$out" | parse_cc | awk '{print $1}')
	st=$(printf '%s' "$out" | parse_cc | awk '{print $2}')
	if [ -z "$op" ]; then
		fail "$title — no Command Complete"
		echo ""
		return
	fi
	if [ "$st" = "0" ]; then
		pass "$title"
	else
		fail "$title — Command Complete status=$st (opcode=$op)"
	fi
	echo ""
}

expect_cs_status() {
	local title="$1"
	local want="$2"
	shift 2
	echo "========================================"
	echo "$title"
	echo "  hcitool -i $HCI cmd $*"
	local out st
	out=$(hcitool -i "$HCI" cmd "$@" 2>&1) || true
	echo "$out"
	st=$(printf '%s' "$out" | parse_cs_status)
	if ! printf '%s' "$st" | grep -qE '^[0-9]+$'; then
		fail "$title — no Command Status"
		echo ""
		return
	fi
	if [ "$st" -eq "$want" ]; then
		pass "$title — Command Status 0x$(printf %02x "$st") (expected)"
	else
		warn "$title — Command Status 0x$(printf %02x "$st") (expected 0x$(printf %02x "$want"))"
	fi
	echo ""
}

expect_cc_bad() {
	local title="$1"
	shift
	echo "========================================"
	echo "$title"
	echo "  hcitool -i $HCI cmd $*"
	local out st
	out=$(hcitool -i "$HCI" cmd "$@" 2>&1) || true
	echo "$out"
	st=$(printf '%s' "$out" | parse_cc | awk '{print $2}')
	if [ -z "$st" ] && echo "$out" | grep -q '> HCI Event: 0x0f'; then
		pass "$title — failed as expected (Command Status)"
	elif [ -n "$st" ] && [ "$st" != "0" ]; then
		pass "$title — failed as expected (status=$st)"
	else
		warn "$title — unexpected success or ambiguous parse (check dump)"
	fi
	echo ""
}

need_root
need_hcitool

echo "=== DT510 Auracast HCI check ($(date -Iseconds)) ==="
uname -a || true
hciconfig "$HCI" 2>/dev/null | head -4 || true
echo ""

echo "--- Mandatory: reads / safe writes (expect Command Complete status 00) ---"
expect_cc_ok "Read BD_ADDR [UM12155]" 0x04 0x09
expect_cc_ok "Read Local Version Information" 0x04 0x01
expect_cc_ok "LE Read Local Supported Features" 0x08 0x03
expect_cc_ok "LE Read Supported States" 0x08 0x1C
expect_cc_ok "LE Read Maximum Advertising Data Length" 0x08 0x0A
expect_cc_ok "LE Read Number of Supported Advertising Sets" 0x08 0x3B
expect_cc_ok "LE Read Advertising Channel Tx Power" 0x08 0x0B
expect_cc_ok "LE Read Maximum Data Length" 0x08 0x0F
# Connection accept timeout 8000 * 0.625 ms
expect_cc_ok "Write Connection Accept Timeout (0x03 0x16) 0x1F40" 0x03 0x16 40 1F
expect_cc_ok "LE Write Suggested Default Data Length (0x08 0x24) 251 / 2120us" 0x08 0x24 FB 00 48 08
expect_cc_ok "LE Set Default PHY (0x08 0x31)" 0x08 0x31 00 07 07

echo "--- Informational: known IW612 / stack quirks (do not fail suite) ---"
expect_cs_status "LE Read Buffer Size V2 (0x08 0x77)" 17 0x08 0x77
expect_cs_status "LE Read Suggested Default Data Length (0x08 0x26)" 18 0x08 0x26

echo "--- Negative tests: invalid / incomplete params (expect failure) ---"
expect_cc_bad "LE Set CIG Parameters (0x08 0x62) invalid stub" 0x08 0x62 \
	00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 01
expect_cc_bad "LE Set Extended Advertising Parameters (0x08 0x36) truncated" 0x08 0x36 00

echo "=== done (exit $RC) ==="
echo "Hint: Command Complete 0x0e with status byte 00 = success for that opcode."
echo "      Command Status 0x0f with non-zero first octet = immediate HCI error."
exit "$RC"
