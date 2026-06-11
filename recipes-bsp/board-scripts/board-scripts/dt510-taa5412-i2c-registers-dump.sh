#!/bin/bash
# SPDX-License-Identifier: MIT
#
# DT510 — read / decode TAA5412-Q1 registers with driver RUNNING.
#
# Michael / hardware team format note:
#   TI PurePath dumps use:  w <i2c_8bit_addr> <reg> <val>
#   DT510 board: 7-bit 0x51 (8-bit write 0xa2). This script reads via i2cget -f
#   when the codec driver is bound; optional --regmap compares regmap debugfs
#   linear addresses (page * 128 + reg).
#
# Page / book:
#   reg 0x00 ← page select; reg 0x7f ← book select (Michael dumps often w … 7f 00).
#   Regmap linear: (page * 128) + reg — e.g. page 0 reg 0x50 → 0x0050.
#
# Quick use (driver bound):
#   sudo dt510-taa5412-i2c-registers-dump.sh
#   sudo dt510-taa5412-i2c-registers-dump.sh -a
#   sudo dt510-taa5412-i2c-registers-dump.sh -p 0 -r 0x50
#   sudo dt510-taa5412-i2c-registers-dump.sh --regmap
#
# Pair with apply:
#   sudo dt510-taa5412-i2c-registers-apply.sh -f taa5412-registers-michael.conf -a 0x51 --verify

set -euo pipefail

BUS=1
ADDR=0x51
PAGE=-1
DUMP_ALL=0
SINGLE_REG=""
SHOW_REGMAP=0
I2C_FORCE=(-f)

usage() {
	cat <<EOF
Usage: $(basename "$0") [-b bus] [-a [addr]|--all] [-p page] [-r reg] [--regmap]

  -b bus       I2C adapter (default: 1 — DT510 &i2c2)
  -a [addr]    7-bit I2C address (default: 0x51); bare -a dumps pages 0–1
  -A addr8     8-bit I2C address (e.g. a2 → 7-bit 0x51)
  -p page      Dump interesting registers on one page (0 or 1)
  -r reg       Single register on current / selected page (hex)
  --regmap     Also grep regmap debugfs linear addresses for each reg

Env: TAA5412_I2C_ADDR — 7-bit or 8-bit before -a/-A

Default (no -p/-r/-a): dump key registers on pages 0 and 1.
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

hexbyte() {
	local v="${1#0x}"
	v="${v#0X}"
	printf '%d' "0x${v}"
}

if [ -n "${TAA5412_I2C_ADDR:-}" ]; then
	ADDR=$(i2c_7bit_from_token "$TAA5412_I2C_ADDR")
fi

while [ $# -gt 0 ]; do
	case "$1" in
	-b) BUS="$2"; shift 2 ;;
	-A) ADDR=$(i2c_7bit_from_token "$2"); shift 2 ;;
	-a)
		if [ $# -gt 1 ] && [[ "$2" =~ ^(0x|0X)?[0-9a-fA-F]+$ ]]; then
			ADDR=$(i2c_7bit_from_token "$2")
			shift 2
		else
			DUMP_ALL=1
			shift
		fi
		;;
	-p) PAGE="$2"; shift 2 ;;
	-r) SINGLE_REG="$2"; shift 2 ;;
	--regmap) SHOW_REGMAP=1; shift ;;
	-h|--help) usage; exit 0 ;;
	*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
	esac
done

if ! command -v i2cget >/dev/null 2>&1; then
	echo "ERR: i2cget not found (install i2c-tools)" >&2
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

CURRENT_PAGE=-1

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

select_page() {
	local page="$1"
	if [ "$page" -eq "$CURRENT_PAGE" ]; then
		return 0
	fi
	i2cset "${I2C_FORCE[@]}" -y "$BUS" "$ADDR" 0x00 "$page" b
	CURRENT_PAGE=$page
}

reg_read() {
	local page="$1" reg="$2"
	select_page "$page"
	i2cget "${I2C_FORCE[@]}" -y "$BUS" "$ADDR" "$reg" b
}

reg_name_hex() {
	local reg="$1"
	case "$reg" in
	$((0x00))) echo "PAGE_SELECT" ;;
	$((0x02))) echo "VREF" ;;
	$((0x13))) echo "INTF4" ;;
	$((0x1a))) echo "PASI0" ;;
	$((0x1e))) echo "PASITXCH1" ;;
	$((0x1f))) echo "PASITXCH2" ;;
	$((0x4d))) echo "VREFCFG" ;;
	$((0x50))) echo "ADCCH1C0" ;;
	$((0x51))) echo "ADCCH1C1" ;;
	$((0x52))) echo "ADCCH1C2" ;;
	$((0x53))) echo "ADCCH1C3" ;;
	$((0x54))) echo "ADCCH1C4" ;;
	$((0x55))) echo "ADCCH2C0" ;;
	$((0x57))) echo "ADCCH2C2" ;;
	$((0x58))) echo "ADCCH2C3" ;;
	$((0x59))) echo "ADCCH2C4" ;;
	$((0x5a))) echo "ADCCH3C0" ;;
	$((0x5b))) echo "ADCCH3C2" ;;
	$((0x5c))) echo "ADCCH3C3" ;;
	$((0x5d))) echo "ADCCH3C4" ;;
	$((0x5e))) echo "ADCCH4C0" ;;
	$((0x76))) echo "CH_EN" ;;
	$((0x78))) echo "PWR_CFG" ;;
	$((0x7f))) echo "BOOK_SELECT" ;;
	$((0x73))) echo "MICBIAS/page1" ;;
	*) echo "" ;;
	esac
}

decode_adcch_c0() {
	local val="$1" label="$2"
	local wide tol cfg imp
	wide=$(( (val >> 0) & 1 ))
	tol=$(( (val >> 2) & 3 ))
	cfg=$(( (val >> 6) & 3 ))
	imp=$(( (val >> 4) & 3 ))
	local wide_s tol_s cfg_s
	wide_s=$([ "$wide" -eq 1 ] && echo "wideband" || echo "normal")
	case "$tol" in
	0) tol_s="AC 100mVpp (DT510 AC-coupled target)" ;;
	1) tol_s="AC/DC 1Vpp" ;;
	2) tol_s="AC/DC rail-rail" ;;
	*) tol_s="CM tol=$tol" ;;
	esac
	case "$cfg" in
	0) cfg_s="Differential" ;;
	1) cfg_s="Single-ended" ;;
	2) cfg_s="SE mux INxP" ;;
	3) cfg_s="SE mux INxM" ;;
	esac
	echo "    ${label}: ${cfg_s}; ${tol_s}; ${wide_s}; imp=${imp}"
}

decode_intf4() {
	local val="$1"
	local ch1 ch2 pdm12 pdm34
	ch1=$(( (val >> 7) & 1 ))
	ch2=$(( (val >> 6) & 1 ))
	pdm12=$(( (val >> 2) & 3 ))
	pdm34=$(( val & 3 ))
	local s1 s2
	s1=$([ "$ch1" -eq 0 ] && echo "Analog" || echo "PDM")
	s2=$([ "$ch2" -eq 0 ] && echo "Analog" || echo "PDM")
	echo "    IN1=${s1} IN2=${s2}; PDM_DIN12_sel=${pdm12} PDM_DIN34_sel=${pdm34}"
}

decode_pasitxch() {
	local val="$1" ch="$2"
	local slot asi_tx
	slot=$(( val & 0x1f ))
	asi_tx=$(( (val >> 5) & 1 ))
	echo "    PASITXCH${ch}: slot=${slot} ASI_TX_EN(bit5)=${asi_tx}"
}

decode_ch_en() {
	local val="$1"
	local a1 a2 a3 a4 d1 d2 d3 d4
	a1=$(( (val >> 7) & 1 ))
	a2=$(( (val >> 6) & 1 ))
	a3=$(( (val >> 5) & 1 ))
	a4=$(( (val >> 4) & 1 ))
	d1=$(( (val >> 3) & 1 ))
	d2=$(( (val >> 2) & 1 ))
	d3=$(( (val >> 1) & 1 ))
	d4=$(( val & 1 ))
	echo "    ADC EN: CH1=${a1} CH2=${a2} CH3=${a3} CH4=${a4} | DAC EN: CH1=${d1} CH2=${d2} CH3=${d3} CH4=${d4}"
}

decode_pwr_cfg() {
	local val="$1"
	local adc dac mic uad vad uag
	adc=$(( (val >> 7) & 1 ))
	dac=$(( (val >> 6) & 1 ))
	mic=$(( (val >> 5) & 1 ))
	uad=$(( (val >> 3) & 1 ))
	vad=$(( (val >> 2) & 1 ))
	uag=$(( (val >> 1) & 1 ))
	echo "    PWR: ADC_PDZ=${adc} DAC_PDZ=${dac} MICBIAS=${mic} UAD=${uad} VAD=${vad} UAG=${uag}"
}

decode_vref() {
	local val="$1"
	local sleep_en active
	sleep_en=$(( (val >> 7) & 1 ))
	active=$(( val & 1 ))
	echo "    VREF: sleep_exit_en=${sleep_en} active=${active}"
}

decode_pasi0() {
	local val="$1"
	local fmt datalen
	fmt=$(( (val >> 6) & 3 ))
	datalen=$(( (val >> 4) & 3 ))
	local fmt_s
	case "$fmt" in
	0) fmt_s="TDM" ;;
	1) fmt_s="I2S" ;;
	2) fmt_s="LJ" ;;
	*) fmt_s="fmt=${fmt}" ;;
	esac
	echo "    PASI0: ${fmt_s} word_len_idx=${datalen} raw=0x$(printf '%02x' "$val")"
}

decode_reg() {
	local page="$1" reg="$2" val="$3"
	case "$reg" in
	$((0x02))) decode_vref "$val" ;;
	$((0x13))) decode_intf4 "$val" ;;
	$((0x1a))) decode_pasi0 "$val" ;;
	$((0x1e))) decode_pasitxch "$val" 1 ;;
	$((0x1f))) decode_pasitxch "$val" 2 ;;
	$((0x50))) decode_adcch_c0 "$val" "ADC1" ;;
	$((0x55))) decode_adcch_c0 "$val" "ADC2" ;;
	$((0x5a))) decode_adcch_c0 "$val" "ADC3" ;;
	$((0x5e))) decode_adcch_c0 "$val" "ADC4" ;;
	$((0x76))) decode_ch_en "$val" ;;
	$((0x78))) decode_pwr_cfg "$val" ;;
	esac
}

dump_one_reg() {
	local page="$1" reg="$2"
	local rb val_n name linear rmap_line
	reg=$(hexbyte "$reg")
	rb=$(reg_read "$page" "$reg") || {
		echo "ERR: read page=$page reg=$(printf '0x%02x' "$reg") failed" >&2
		return 1
	}
	val_n=$(hexbyte "$rb")
	name=$(reg_name_hex "$reg")
	linear=$(regmap_linear_addr "$page" "$reg")
	printf 'p%-1d 0x%02x 0x%02x' "$page" "$reg" "$val_n"
	[ -n "$name" ] && printf '  %-12s' "$name"
	printf '  linear=0x%04x' "$linear"
	if [ "$SHOW_REGMAP" -eq 1 ] && [ -n "$REGMAP_DBG" ]; then
		rmap_line=$(grep -E "^$(printf '%04x' "$linear"):" "$REGMAP_DBG/registers" 2>/dev/null || true)
		[ -n "$rmap_line" ] && printf '  regmap: %s' "$rmap_line"
	fi
	printf '\n'
	decode_reg "$page" "$reg" "$val_n" || true
}

interesting_regs_page0=(
	0x00 0x02 0x13 0x1a 0x1e 0x1f 0x4d
	0x50 0x51 0x52 0x53 0x54 0x55 0x57 0x58 0x59
	0x5a 0x5b 0x5c 0x5d 0x5e
	0x76 0x78 0x7f
)

interesting_regs_page1=(
	0x00 0x73
)

dump_page() {
	local page="$1"
	echo "=== page $page (bus=$BUS addr=$(printf '0x%02x' "$ADDR") driver=${DRV:-none}) ==="
	if [ "$page" -eq 0 ]; then
		for reg in "${interesting_regs_page0[@]}"; do
			dump_one_reg "$page" "$reg"
		done
	elif [ "$page" -eq 1 ]; then
		for reg in "${interesting_regs_page1[@]}"; do
			dump_one_reg "$page" "$reg"
		done
	else
		echo "WARN: no curated reg list for page $page — dumping 0x00..0x7f" >&2
		local r
		for r in $(seq 0 127); do
			dump_one_reg "$page" "$r"
		done
	fi
}

echo "TAA5412 register dump ($(date -Iseconds)) node=${I2C_NODE:-none} bound=$DRIVER_BOUND"
[ "$DRIVER_BOUND" -eq 0 ] && echo "WARN: no driver bound — reads may still work" >&2

if [ -n "$SINGLE_REG" ]; then
	p="${PAGE:-0}"
	dump_one_reg "$p" "$(hexbyte "$SINGLE_REG")"
	exit 0
fi

if [ "$PAGE" -ge 0 ] 2>/dev/null; then
	dump_page "$PAGE"
	exit 0
fi

dump_page 0
dump_page 1
