#!/bin/sh
# DT510 TAA5412-Q1 driver mic: boot ALSA mixer defaults (pcm6240 / driver_mic).
# Regbin PRE_POWER_UP also programs MICBIAS and digital gains; this script is an
# amixer-only backup after the card probes (no Michael I2C apply).
#
# Optional env: TAA5412_MIXER (default driver_mic), TAA5412_CH1_DIGI (default 240),
# TAA5412_CH1_FINE (default 8 — reg 0x53 lower nibble / Ch1 Fine ALSA control).

MIX=${TAA5412_MIXER:-driver_mic}
CH1_DIGI=${TAA5412_CH1_DIGI:-240}
CH1_FINE=${TAA5412_CH1_FINE:-8}
CH_MUTE_DIGI=0
CH_FINE=${TAA5412_CH_FINE:-8}

NAME=taa5412-init
log() {
	logger -t "$NAME" "$@"
}

resolve_hwctl() {
	c=$(arecord -l 2>/dev/null | sed -n 's/^card \([0-9]\{1,\}\):.*taa5412.*/\1/p' | head -n1)
	if [ -n "$c" ]; then
		printf 'hw:%s' "$c"
	fi
}

# Return first mixer control name matching "ChN Kind" (pcm6240: Simple mixer control '…Ch1 Digi').
find_ch_ctrl() {
	_ctl=$1
	_ch=$2
	_kind=$3
	amixer -D "$_ctl" scontrols 2>/dev/null \
		| sed -n "s/.*'\\([^']*Ch${_ch} ${_kind}[^']*\\)'.*/\\1/p" \
		| head -n1
}

set_cset() {
	_ctl=$1
	_name=$2
	_val=$3
	[ -n "$_name" ] || return 0
	if amixer -D "$_ctl" cget name="$_name" >/dev/null 2>&1; then
		amixer -q -D "$_ctl" cset name="$_name" "$_val" 2>/dev/null && return 0
	fi
	amixer -q -D "$_ctl" sset "$_name" "$_val" 2>/dev/null || true
}

n=0
while [ "$n" -lt 40 ]; do
	if amixer -D "$MIX" info >/dev/null 2>&1; then
		break
	fi
	sleep 1
	n=$((n + 1))
done

CTL=$MIX
if ! amixer -D "$CTL" info >/dev/null 2>&1; then
	CTL=$(resolve_hwctl)
	if [ -z "$CTL" ] || ! amixer -D "$CTL" info >/dev/null 2>&1; then
		log "WARN: no TAA5412 mixer (try amixer -D $MIX; card id taa5412codec per /proc/asound/cards)"
		exit 0
	fi
	log "NOTICE: using $CTL instead of named mixer $MIX"
fi

set_cset "$CTL" "$(find_ch_ctrl "$CTL" 1 Digi)" "$CH1_DIGI"
set_cset "$CTL" "$(find_ch_ctrl "$CTL" 1 Fine)" "$CH1_FINE"
set_cset "$CTL" "$(find_ch_ctrl "$CTL" 2 Digi)" "$CH_MUTE_DIGI"
set_cset "$CTL" "$(find_ch_ctrl "$CTL" 2 Fine)" "$CH_FINE"
set_cset "$CTL" "$(find_ch_ctrl "$CTL" 3 Digi)" "$CH_MUTE_DIGI"
set_cset "$CTL" "$(find_ch_ctrl "$CTL" 3 Fine)" "$CH_FINE"
set_cset "$CTL" "$(find_ch_ctrl "$CTL" 4 Digi)" "$CH_MUTE_DIGI"
set_cset "$CTL" "$(find_ch_ctrl "$CTL" 4 Fine)" "$CH_FINE"

log "OK: driver_mic Ch1 Digi=$CH1_DIGI Fine=$CH1_FINE; Ch2-4 Digi=0 Fine=$CH_FINE (mixer=$MIX)"

exit 0
