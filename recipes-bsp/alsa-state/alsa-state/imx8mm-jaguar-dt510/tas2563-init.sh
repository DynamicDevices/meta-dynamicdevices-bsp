#!/bin/sh
# DT510 TAS2563: boot mixer defaults via ctl name "drivers" (/etc/asound.conf).
# Uses TAS2781-comlib volume enum index (see kernel tas2563_dvc_table): 0=mute-ish, 255≈+6 dB.
#
# Optional env: TAS2563_MIXER (default drivers), TAS2563_BOOT_DVC (default 204 ≈ −20 dB),
# TAS2563_DVC_CTRL (default "Speaker Digital Volume").

MIX=${TAS2563_MIXER:-drivers}
VOL=${TAS2563_BOOT_DVC:-204}
DVC=${TAS2563_DVC_CTRL:-"Speaker Digital Volume"}

NAME=tas2563-init
log() {
	logger -t "$NAME" "$@"
}

resolve_hwctl() {
	c=$(aplay -l 2>/dev/null | sed -n 's/^card \([0-9]\{1,\}\):.*tas2563.*/\1/p' | head -n1)
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
		log "WARN: no TAS2563 mixer (try amixer -D $MIX; card id tas2563audio per /proc/asound/cards)"
		exit 0
	fi
	log "NOTICE: using $CTL instead of named mixer $MIX"
fi

if amixer -D "$CTL" cget name='ASI1 Sel' >/dev/null 2>&1; then
	amixer -q -D "$CTL" cset name='ASI1 Sel' 1 2>/dev/null || true
	log "OK: amixer -D $CTL ASI1 Sel=1 (Left)"
fi

if amixer -D "$CTL" cget name="$DVC" >/dev/null 2>&1; then
	amixer -q -D "$CTL" cset name="$DVC" "$VOL" 2>/dev/null || true
	log "OK: amixer -D $CTL $DVC=$VOL (index; mixer=$MIX)"
elif amixer -D "$CTL" cget name="Digital Volume Control" >/dev/null 2>&1; then
	# snd_soc_tas2562 in-kernel driver (IMAGE 438+): 0–110 dB scale, not TAS2781 comlib index.
	DVC2=${TAS2562_BOOT_DVC:-80}
	amixer -q -D "$CTL" cset name="Digital Volume Control" "$DVC2" 2>/dev/null || true
	log "OK: amixer -D $CTL Digital Volume Control=$DVC2 (tas2562 fallback; mixer=$MIX)"
else
	log "NOTICE: neither '$DVC' nor 'Digital Volume Control' on $CTL — check amixer -D $CTL scontrols"
fi

exit 0
