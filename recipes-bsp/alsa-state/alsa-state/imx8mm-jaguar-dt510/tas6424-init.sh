#!/bin/sh
# DT510 TAS6424E-Q1: boot mixer defaults. Uses ctl name "tannoys" from /etc/asound.conf.
# Optional env overrides: TAS6424_MIXER, TAS6424_BOOT_VOL, TAS6424_VOL_CH1, TAS6424_VOL_CH2–CH4 strings.

VOL=${TAS6424_BOOT_VOL:-16}
MIX=${TAS6424_MIXER:-tannoys}
VOL_CH1=${TAS6424_VOL_CH1:-"Speaker Driver CH1"}
VOL_CH2=${TAS6424_VOL_CH2:-"Speaker Driver CH2"}
VOL_CH3=${TAS6424_VOL_CH3:-"Speaker Driver CH3"}
VOL_CH4=${TAS6424_VOL_CH4:-"Speaker Driver CH4"}

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

amixer -q -D "$CTL" sset "$VOL_CH1" "$VOL" 2>/dev/null || true
amixer -q -D "$CTL" sset "$VOL_CH2" "$VOL" 2>/dev/null || true
amixer -q -D "$CTL" sset "$VOL_CH3" "$VOL" 2>/dev/null || true
amixer -q -D "$CTL" sset "$VOL_CH4" "$VOL" 2>/dev/null || true
amixer -q -D "$CTL" sset 'Auto Diagnostics' off 2>/dev/null || true

log "OK: amixer -D $CTL CH1–CH4=$VOL AutoDiag off (mixer=$MIX)"

exit 0
