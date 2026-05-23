#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
#
# DT510 — apply TAA5412-Q1 register table with driver RUNNING.
# Path B (tac5x1x-codec @ 1-0051) and Path A (pcm6240) — do NOT unbind for bench tuning.
#
# Write path (driver bound):
#   i2cset -f / i2cget -f  — bypasses kernel I2C client lock; verified on target 422.
# Regmap debugfs (/sys/kernel/debug/regmap/1-0051/registers) is READ-ONLY on LmP images;
# writes return EINVAL. Use debugfs for read/dump only (--verify uses i2cget -f when bound).
#
# Page / addressing:
#   I2C (page select): write reg 0x00 ← page number, then reg on that page.
#   Regmap linear map (pcm6240 / tac5x1x): addr = (page * 128) + reg — e.g. page 0 reg 0x50 → 0x50.
#
# Config formats:
#   page  reg  value  [delay_ms]   # standard table
#   w <addr> <reg> <val>           # Michael TI dump (file addr ignored; use -a / -A for board)
#
# ── Hardware team cheat sheet (driver stays bound) ─────────────────────────────
#
#   docker stop vix-apps-avm-1          # if AVM holds the mic
#   grep taa5412 /proc/asound/cards     # expect taa5412codec when sound card probed
#
#   sudo dt510-taa5412-i2c-registers-apply.sh -f taa5412-registers-michael.conf -a 0x51 --verify
#
#   # Record 5 s (idle room — no speech)
#   arecord -D driver_mic -f S16_LE -c 2 -r 48000 -d 5 /tmp/driver_mic.wav
#
#   # Record while speaking at driver mic; check peak
#   arecord -D driver_mic -f S16_LE -c 2 -r 48000 -d 5 /tmp/driver_mic.wav
#   python3 -c "
#   import wave, struct
#   w=wave.open('/tmp/driver_mic.wav')
#   peak=max(abs(s) for f in w.readframes(w.getnframes()) for s in struct.unpack('<'+'h'*(len(f)//2), f))
#   print('peak', peak, '(expect >>0 when mic live)')
#   "
#
#   # Apply registers DURING capture (two terminals, or background arecord)
#   arecord -D driver_mic -f S16_LE -c 2 -r 48000 -d 10 /tmp/during.wav &
#   sudo dt510-taa5412-i2c-registers-apply.sh -f taa5412-registers-michael.conf -a 0x51 --verify
#   wait
#
#   # TI tac5x1x ALSA controls (when card taa5412codec present — amixer -D driver_mic)
#   amixer -D driver_mic              # IN1 Source Mux, ADC config, ASI_TX capture switches
#   amixer -D driver_mic sget 'IN1 Source Mux'
#   amixer -D driver_mic sget 'ADC1 Full-Scale Capture Volume'
#   amixer -D driver_mic sget 'ADC1 Digital Capture Volume'
#   amixer -D driver_mic sget 'ASI_TX_CH1_EN Capture Switch'
#   amixer -D driver_mic sget 'IN_CH1_EN Capture Switch'
#
# ───────────────────────────────────────────────────────────────────────────────

set -euo pipefail

BUS=1
ADDR=0x51
CONF="${TAA5412_REGS_CONF:-/usr/share/board-scripts/taa5412-registers-michael.conf}"
VERIFY=0
DRY_RUN=0
MODE=auto
STRICT_FILE_ADDR=0
FILE_ADDR_WARNED=0

usage() {
	cat <<EOF
Usage: $(basename "$0") [-b bus] [-a addr|-A addr8] [-f conf] [--verify] [-n] [-m mode]

  -b bus       I2C adapter (default: 1 — DT510 &i2c2)
  -a addr      7-bit I2C address (default: 0x51, or TAA5412_I2C_ADDR env)
  -A addr8     8-bit I2C address (e.g. a2 → 7-bit 0x51; write/read forms differ by +1)
  -f conf      Register table (default: $CONF)
  -m mode      auto | i2c | i2c-force | regmap (default: auto)
               auto: i2c-force when codec driver bound, else plain i2c
  --verify     Read back each register after write (i2cget -f when driver bound)
  --strict-addr  Fail if Michael-format file addr != target (-a/-A)
  -n           Dry run — print commands only

Env: TAA5412_I2C_ADDR — 7-bit (0x51) or 8-bit (0xa2) before -a/-A

Config formats:
  page  reg  value  [delay_ms]   # comment
  w <i2c_addr> <reg> <val>      # Michael dump; writes use -a target, not file addr
EOF
}

i2c_7bit_from_token() {
	local t="${1#0x}"
	t="${t#0X}"
	t="${t,,}"
	local n=$((16#$t))
	if [ "$n" -ge 128 ]; then
		echo $((n >> 1))
	else
		echo "$n"
	fi
}

if [ -n "${TAA5412_I2C_ADDR:-}" ]; then
	ADDR=$(i2c_7bit_from_token "$TAA5412_I2C_ADDR")
fi

while [ $# -gt 0 ]; do
	case "$1" in
	-b) BUS="$2"; shift 2 ;;
	-a) ADDR=$(i2c_7bit_from_token "$2"); shift 2 ;;
	-A) ADDR=$(i2c_7bit_from_token "$2"); shift 2 ;;
	-f) CONF="$2"; shift 2 ;;
	-m) MODE="$2"; shift 2 ;;
	--verify) VERIFY=1; shift ;;
	--strict-addr) STRICT_FILE_ADDR=1; shift ;;
	-n) DRY_RUN=1; shift ;;
	-h|--help) usage; exit 0 ;;
	*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
	esac
done

case "$MODE" in
	auto|i2c|i2c-force|regmap) ;;
	*) echo "ERR: invalid -m mode: $MODE" >&2; exit 2 ;;
esac

hexbyte() {
	local v="${1#0x}"
	v="${v#0X}"
	printf '%d' "0x${v}"
}

warn_file_addr_mismatch() {
	local file_7="$1"
	if [ "$file_7" -eq "$ADDR" ]; then
		return 0
	fi
	if [ "$STRICT_FILE_ADDR" -eq 1 ]; then
		echo "ERR: file I2C addr $(printf '0x%02x' "$file_7") != target $(printf '0x%02x' "$ADDR") (use --strict-addr off or fix file)" >&2
		exit 1
	fi
	if [ "$FILE_ADDR_WARNED" -eq 0 ]; then
		echo "WARN: Michael-format file addr $(printf '0x%02x' "$file_7") != target $(printf '0x%02x' "$ADDR"); all writes go to target (-a)." >&2
		FILE_ADDR_WARNED=1
	fi
}

if [ ! -r "$CONF" ]; then
	echo "ERR: config not readable: $CONF" >&2
	exit 1
fi

if ! command -v i2cset >/dev/null 2>&1 || ! command -v i2cget >/dev/null 2>&1; then
	echo "ERR: i2cset/i2cget not found (install i2c-tools)" >&2
	exit 1
fi

I2C_DEV="/dev/i2c-${BUS}"
if [ ! -c "$I2C_DEV" ]; then
	echo "ERR: $I2C_DEV missing" >&2
	exit 1
fi

I2C_NODE=""
for p in /sys/bus/i2c/devices/*-$(printf '%04x' "$ADDR" | sed 's/^0*//')/driver; do
	[ -e "$p" ] || continue
	I2C_NODE="${p%/driver}"
	break
done
if [ -z "$I2C_NODE" ]; then
	for p in /sys/bus/i2c/devices/*-0051/driver; do
		[ -e "$p" ] || continue
		I2C_NODE="${p%/driver}"
		break
	done
fi

DRIVER_BOUND=0
DRV=""
if [ -n "$I2C_NODE" ] && [ -L "${I2C_NODE}/driver" ]; then
	DRIVER_BOUND=1
	DRV=$(basename "$(readlink "${I2C_NODE}/driver")")
fi

REGMAP_DBG=""
if [ -n "$I2C_NODE" ] && [ -d "/sys/kernel/debug/regmap/$(basename "$I2C_NODE")" ]; then
	REGMAP_DBG="/sys/kernel/debug/regmap/$(basename "$I2C_NODE")"
fi

if [ "$MODE" = "auto" ]; then
	if [ "$DRIVER_BOUND" -eq 1 ]; then
		MODE=i2c-force
	else
		MODE=i2c
	fi
fi

if [ "$MODE" = "i2c" ] && [ "$DRIVER_BOUND" -eq 1 ]; then
	echo "WARN: driver '$DRV' bound — plain i2cset will fail (Device busy)." >&2
	echo "      Use default (auto → i2c-force) or -m i2c-force." >&2
fi

if [ "$MODE" = "regmap" ]; then
	if [ -z "$REGMAP_DBG" ]; then
		echo "ERR: regmap debugfs missing for $(basename "$I2C_NODE" 2>/dev/null || echo '?')" >&2
		exit 1
	fi
	if [ -w "${REGMAP_DBG}/registers" ] 2>/dev/null; then
		echo "INFO: regmap debugfs writes available at ${REGMAP_DBG}/registers"
	else
		echo "WARN: ${REGMAP_DBG}/registers is read-only on this kernel — using i2c-force for writes." >&2
		MODE=i2c-force
	fi
fi

echo "mode=$MODE bus=$BUS addr=$(printf '0x%02x' "$ADDR") node=${I2C_NODE:-none} driver=${DRV:-none}"

CURRENT_PAGE=-1
LINE_NO=0
FAIL=0

I2C_FORCE_FLAG=()
[ "$MODE" = "i2c-force" ] && I2C_FORCE_FLAG=(-f)

regmap_linear_addr() {
	local page="$1" reg="$2"
	echo $((page * 128 + reg))
}

regmap_read_hex() {
	local page="$1" reg="$2"
	local linear rb
	linear=$(regmap_linear_addr "$page" "$reg")
	rb=$(grep -E "^$(printf '%04x' "$linear"):" "$REGMAP_DBG/registers" 2>/dev/null | awk '{print $2}')
	[ -n "$rb" ] && echo "$rb"
}

reg_write() {
	local page="$1" reg="$2" val="$3"
	if [ "$DRY_RUN" -eq 1 ]; then
		case "$MODE" in
		i2c-force)
			echo "i2cset -f -y $BUS $ADDR $(printf '0x%02x' "$reg") $(printf '0x%02x' "$val") b"
			;;
		i2c)
			echo "i2cset -y $BUS $ADDR $(printf '0x%02x' "$reg") $(printf '0x%02x' "$val") b"
			;;
		regmap)
			echo "echo $(printf '0x%x' "$(regmap_linear_addr "$page" "$reg")") $(printf '0x%x' "$val") > ${REGMAP_DBG}/registers"
			;;
		esac
		return 0
	fi
	case "$MODE" in
	i2c|i2c-force)
		if ! i2cset "${I2C_FORCE_FLAG[@]}" -y "$BUS" "$ADDR" "$reg" "$val" b 2>/tmp/taa5412-i2c.err; then
			echo "ERR: i2cset reg $(printf '0x%02x' "$reg") val $(printf '0x%02x' "$val"): $(cat /tmp/taa5412-i2c.err)" >&2
			return 1
		fi
		;;
	regmap)
		local linear
		linear=$(regmap_linear_addr "$page" "$reg")
		if ! echo "$(printf '%#x' "$linear") $(printf '%#x' "$val")" >"${REGMAP_DBG}/registers" 2>/tmp/taa5412-i2c.err; then
			echo "ERR: regmap write $(printf '0x%04x' "$linear") val $(printf '0x%02x' "$val"): $(cat /tmp/taa5412-i2c.err)" >&2
			return 1
		fi
		;;
	esac
	return 0
}

reg_read() {
	local page="$1" reg="$2"
	if [ "$DRY_RUN" -eq 1 ]; then
		case "$MODE" in
		i2c-force) echo "? i2cget -f reg $(printf '0x%02x' "$reg")" ;;
		i2c) echo "? i2cget reg $(printf '0x%02x' "$reg")" ;;
		regmap) echo "? regmap $(printf '0x%04x' "$(regmap_linear_addr "$page" "$reg")")" ;;
		esac
		return 0
	fi
	local rb=""
	case "$MODE" in
	i2c|i2c-force)
		rb=$(i2cget "${I2C_FORCE_FLAG[@]}" -y "$BUS" "$ADDR" "$reg" b 2>/dev/null) || return 1
		;;
	regmap)
		rb=$(regmap_read_hex "$page" "$reg") || return 1
		;;
	esac
	echo "$rb"
}

select_page() {
	local page="$1"
	if [ "$page" -eq "$CURRENT_PAGE" ]; then
		return 0
	fi
	echo "page -> $page (reg 0x00)"
	reg_write "$page" 0x00 "$page" || return 1
	CURRENT_PAGE=$page
	return 0
}

apply_write() {
	local page_n="$1" reg_n="$2" val_n="$3" delay_n="${4:-0}"

	if [ "$reg_n" -eq 0 ]; then
		if ! select_page "$val_n"; then
			return 1
		fi
		page_n=$val_n
		if [ "$VERIFY" -eq 1 ] && [ "$DRY_RUN" -eq 0 ]; then
			local rb rb_n
			rb=$(reg_read "$page_n" 0x00) || rb=""
			if [ -z "$rb" ]; then
				echo "ERR: verify page select reg 0x00: read failed" >&2
				return 1
			fi
			rb_n=$(hexbyte "$rb")
			if [ "$rb_n" -ne "$val_n" ]; then
				echo "ERR: verify page select: wrote page $val_n read $(printf '0x%02x' "$rb_n")" >&2
				return 1
			fi
			echo "  OK readback page $(printf '0x%02x' "$rb_n")"
		fi
		return 0
	else
		if [ "$CURRENT_PAGE" -lt 0 ]; then
			echo "ERR: line $LINE_NO: reg $(printf '0x%02x' "$reg_n") before page select (reg 0x00)" >&2
			return 1
		fi
		if ! select_page "$CURRENT_PAGE"; then
			return 1
		fi
		page_n=$CURRENT_PAGE
	fi

	echo "write page=$page_n reg=$(printf '0x%02x' "$reg_n") val=$(printf '0x%02x' "$val_n") linear=$(printf '0x%04x' "$(regmap_linear_addr "$page_n" "$reg_n")")"
	if ! reg_write "$page_n" "$reg_n" "$val_n"; then
		return 1
	fi

	if [ "$VERIFY" -eq 1 ]; then
		local rb rb_n
		rb=$(reg_read "$page_n" "$reg_n") || rb=""
		if [ "$DRY_RUN" -eq 0 ]; then
			if [ -z "$rb" ]; then
				echo "ERR: verify reg $(printf '0x%02x' "$reg_n"): read failed" >&2
				return 1
			fi
			rb_n=$(hexbyte "$rb")
			if [ "$rb_n" -ne "$val_n" ]; then
				echo "ERR: verify reg $(printf '0x%02x' "$reg_n"): wrote $(printf '0x%02x' "$val_n") read $(printf '0x%02x' "$rb_n")" >&2
				return 1
			fi
			echo "  OK readback $(printf '0x%02x' "$rb_n")"
		fi
	fi

	if [ "$delay_n" -gt 0 ]; then
		[ "$DRY_RUN" -eq 1 ] && echo "sleep ${delay_n}ms"
		[ "$DRY_RUN" -eq 0 ] && sleep "$(awk "BEGIN {printf \"%.3f\", $delay_n/1000}")"
	fi
	return 0
}

while IFS= read -r line || [ -n "$line" ]; do
	LINE_NO=$((LINE_NO + 1))
	line="${line%%#*}"
	line="${line#"${line%%[![:space:]]*}"}"
	[ -z "$line" ] && continue

	if [ "${line%% *}" = "w" ]; then
		read -r _w file_addr reg val _rest <<<"$line"
		if [ -z "${file_addr:-}" ] || [ -z "${reg:-}" ] || [ -z "${val:-}" ]; then
			echo "ERR: line $LINE_NO: Michael format needs: w addr reg val" >&2
			FAIL=1
			continue
		fi
		file_7=$(i2c_7bit_from_token "$file_addr")
		warn_file_addr_mismatch "$file_7"
		reg_n=$(hexbyte "$reg")
		val_n=$(hexbyte "$val")
		if ! apply_write 0 "$reg_n" "$val_n"; then
			FAIL=1
		fi
		continue
	fi

	read -r page reg val delay_ms _rest <<<"$line"
	if [ -z "${page:-}" ] || [ -z "${reg:-}" ] || [ -z "${val:-}" ]; then
		echo "ERR: line $LINE_NO: need page reg value (or w addr reg val): $line" >&2
		FAIL=1
		continue
	fi

	page_n=$((page))
	reg_n=$(hexbyte "$reg")
	val_n=$(hexbyte "$val")
	delay_n=0
	if [ -n "${delay_ms:-}" ] && [[ "$delay_ms" =~ ^[0-9]+$ ]]; then
		delay_n=$delay_ms
	fi

	if ! select_page "$page_n"; then
		FAIL=1
		continue
	fi

	if ! apply_write "$page_n" "$reg_n" "$val_n" "$delay_n"; then
		FAIL=1
	fi
done <"$CONF"

if [ "$FAIL" -ne 0 ]; then
	echo "=== failed (see errors above) ===" >&2
	exit 1
fi
echo "=== done ($CONF) ==="
exit 0
