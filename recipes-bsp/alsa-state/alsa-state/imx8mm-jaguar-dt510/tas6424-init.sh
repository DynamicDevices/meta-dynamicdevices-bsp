#!/bin/sh
# DT510 speaker driver (TAS6424E-Q1): Linux exposes 4 ALSA mixer channels today.
# HW currently uses two differential pairs on OUT2/OUT3 only; production (VIX) moves
# to the 2-channel part (TAS6422E-Q1) — then expect 2-channel controls / DT updates.
#
# Prefer named mixer PCM from /etc/asound.conf ("tannoys" → tas6424-classd card); see
# /etc/default/tas6424-alsa for TAS6424_VOL_* ⇔ silicon channel mapping.

VOL=${TAS6424_BOOT_VOL:-16}

# shellcheck disable=SC1091
[ -r /etc/default/tas6424-alsa ] && . /etc/default/tas6424-alsa

MIX=${TAS6424_MIXER:-tannoys}
VOL_CH1=${TAS6424_VOL_CH1:-'Speaker Driver CH1'}
VOL_T1=${TAS6424_VOL_TANNOY_1:-'Speaker Driver CH2'}
VOL_T2=${TAS6424_VOL_TANNOY_2:-'Speaker Driver CH3'}
VOL_CH4=${TAS6424_VOL_CH4:-'Speaker Driver CH4'}

NAME=tas6424-init
log() {
	logger -t "$NAME" "$@"
}

resolve_hwctl() {
	local c
	c=$(aplay -l 2>/dev/null | sed -n 's/^card \([0-9]\{1,\}\):.*tas6424.*/\1/p' | head -n1)
	if [ -n "$c" ]; then
		printf 'hw:%s' "$c"
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
		log "WARN: no TAS6424 mixer (try amixer -D $MIX or check card id tas6424-classd in /proc/asound/cards)"
		exit 0
	fi
	log "NOTICE: using $CTL (named mixer $MIX unavailable — check /etc/asound.conf and card string)"
fi

amixer -q -D "$CTL" sset "$VOL_CH1" "$VOL" 2>/dev/null || true
amixer -q -D "$CTL" sset "$VOL_T1" "$VOL" 2>/dev/null || true
amixer -q -D "$CTL" sset "$VOL_T2" "$VOL" 2>/dev/null || true
amixer -q -D "$CTL" sset "$VOL_CH4" "$VOL" 2>/dev/null || true
amixer -q -D "$CTL" sset 'Auto Diagnostics' off 2>/dev/null || true

log "OK: amixer -D $CTL CH1 + Tannoys(CH2/CH3) + CH4 = $VOL AutoDiag off (named mixer=$MIX)"

exit 0
