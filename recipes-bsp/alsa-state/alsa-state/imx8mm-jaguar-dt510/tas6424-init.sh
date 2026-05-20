#!/bin/sh
# DT510 TAS6424E-Q1: boot passenger tannoy horn mixer defaults (ctl "tannoys" from /etc/asound.conf).
# Passenger tannoy PA levels: kernel may expose "Tannoy CH1"–CH4 (patch 0026) or legacy "Speaker Driver CHn".
# Optional env overrides: TAS6424_MIXER, TAS6424_BOOT_VOL, TAS6424_VOL_CH1, TAS6424_VOL_CH2–CH4 strings.
# TAS6424_BOOT_VOL is dB for amixer sset -- NNdB (lab default -17.5). Use -- before negative dB.
# Kernel 0026: Tannoy CHn TLV controls; lab/boot use dB sset -- (not linear index 20).

VOL=${TAS6424_BOOT_VOL:--17.5}
VOL_DB=$(echo "$VOL" | sed 's/[dD][bB]$//')
MIX=${TAS6424_MIXER:-tannoys}
VOL_CH1=${TAS6424_VOL_CH1:-}
VOL_CH2=${TAS6424_VOL_CH2:-}
VOL_CH3=${TAS6424_VOL_CH3:-}
VOL_CH4=${TAS6424_VOL_CH4:-}

NAME=tas6424-init
log() {
	logger -t "$NAME" "$@"
}

resolve_hwctl() {
	c=$(aplay -l 2>/dev/null | sed -n 's/^card \([0-9]\{1,\}\):.*tas6424.*/\1/p' | head -n1)
	if [ -n "$c" ]; then
		printf 'hw:%s' "$c"
	fi
}

# Probe simple control names (matches alsamixer and AVM _resolve_tannoy_ch_controls).
probe_ch_names() {
	if [ -n "$VOL_CH1" ] && [ -n "$VOL_CH2" ] && [ -n "$VOL_CH3" ] && [ -n "$VOL_CH4" ]; then
		printf '%s\n%s\n%s\n%s' "$VOL_CH1" "$VOL_CH2" "$VOL_CH3" "$VOL_CH4"
		return 0
	fi
	if amixer -D "$1" scontrols 2>/dev/null | grep -q 'Tannoy CH1'; then
		printf '%s\n' 'Tannoy CH1' 'Tannoy CH2' 'Tannoy CH3' 'Tannoy CH4'
	elif amixer -D "$1" scontrols 2>/dev/null | grep -q 'Speaker Driver CH1'; then
		printf '%s\n' 'Speaker Driver CH1' 'Speaker Driver CH2' 'Speaker Driver CH3' 'Speaker Driver CH4'
	else
		log "WARN: could not probe CH1–CH4 on $1"
		return 1
	fi
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
		log "WARN: no TAS6424 mixer (try amixer -D $MIX; card id is tas6424classd per /proc/asound/cards)"
		exit 0
	fi
	log "NOTICE: using $CTL instead of named mixer $MIX"
fi

CH_LIST=$(probe_ch_names "$CTL") || exit 0

set_ch_vol() {
	_ch=$1
	amixer -q -D "$CTL" sset "$_ch" -- "${VOL_DB}dB" 2>/dev/null || true
}

echo "$CH_LIST" | while read -r ch; do
	[ -n "$ch" ] || continue
	set_ch_vol "$ch"
done
amixer -q -D "$CTL" sset 'Auto Diagnostics' off 2>/dev/null || true

log "OK: amixer -D $CTL CH1–CH4=${VOL_DB}dB (sset --) AutoDiag off (mixer=$MIX)"

exit 0
