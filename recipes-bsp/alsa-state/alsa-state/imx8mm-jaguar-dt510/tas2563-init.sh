#!/bin/sh
# DT510 TAS2563: boot mixer defaults via ctl name "drivers" (/etc/asound.conf).
# TAS2781 comlib: "Speaker Digital Volume" index 0–255. IMAGE 438+ tas2562: DVC 0–110 + Amp Gain 0–28.
#
# Hardware spec: 30 W per channel. Michael bench (2026-05): driver cab at DVC 92 + amp 23 drew ~90 W.
# Amp Gain sets analog drive (dominant power term); keep amp ≤20 for production. DVC 110 + amp 28 is
# lab-debug only — forbidden for sustained play (clips + ~3× over power spec).
#
# Optional env:
#   TAS2563_MIXER (default drivers), TAS2563_BOOT_DVC (default 204, comlib only),
#   TAS2563_DVC_CTRL (default "Speaker Digital Volume"),
#   TAS2562_BOOT_DVC (default 85 — Digital Volume Control; Sentai 82, avoid 110 sustained),
#   TAS2562_BOOT_AMP_GAIN (default 20 — Amp Gain Volume ~18 dB; Sentai reference, ≤30 W target).

MIX=${TAS2563_MIXER:-drivers}
VOL=${TAS2563_BOOT_DVC:-204}
DVC=${TAS2563_DVC_CTRL:-"Speaker Digital Volume"}
DVC2=${TAS2562_BOOT_DVC:-85}
AMP=${TAS2562_BOOT_AMP_GAIN:-20}

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

set_amp_gain() {
	ctl_dev=$1
	for ag_name in "Amp Gain Volume" "Amp Gain"; do
		if amixer -D "$ctl_dev" cget name="$ag_name" >/dev/null 2>&1; then
			amixer -q -D "$ctl_dev" cset name="$ag_name" "$AMP" 2>/dev/null || true
			log "OK: amixer -D $ctl_dev $ag_name=$AMP"
			return 0
		fi
	done
	return 1
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
	amixer -q -D "$CTL" cset name="Digital Volume Control" "$DVC2" 2>/dev/null || true
	log "OK: amixer -D $CTL Digital Volume Control=$DVC2 (tas2562; mixer=$MIX)"
else
	log "NOTICE: neither '$DVC' nor 'Digital Volume Control' on $CTL — check amixer -D $CTL scontrols"
fi

if ! set_amp_gain "$CTL"; then
	log "NOTICE: no Amp Gain Volume on $CTL (tas2562 driver may not expose it yet)"
fi

exit 0
