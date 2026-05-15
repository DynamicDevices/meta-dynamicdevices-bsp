#!/bin/sh
# DT510 TAS6424E class-D: board routes loads on OUT2/OUT3 — keep CH1/CH4 down, raise CH2/CH3.
# Card index is not fixed (Loopback is card 0); resolve by aplay -l.

NAME=tas6424-init
log() {
	logger -t "$NAME" "$@"
}

resolve_card() {
	aplay -l 2>/dev/null | sed -n 's/^card \([0-9]\{1,\}\):.*tas6424.*/\1/p' | head -n1
}

n=0
while [ "$n" -lt 40 ]; do
	CARD=$(resolve_card)
	if [ -n "$CARD" ]; then
		break
	fi
	sleep 1
	n=$((n + 1))
done

if [ -z "$CARD" ]; then
	log "WARN: no TAS6424 ALSA card in aplay —l yet; skipping mixer defaults"
	exit 0
fi

if ! amixer -c "$CARD" info >/dev/null 2>&1; then
	log "WARN: amixer -c $CARD failed"
	exit 0
fi

# Per imx8mm-jaguar-dt510.dts: use Speaker Driver CH2/CH3; leave CH1/CH4 muted at 0.
amixer -q -c "$CARD" cset name='Speaker Driver CH1' 0 2>/dev/null || true
amixer -q -c "$CARD" cset name='Speaker Driver CH2' 200 2>/dev/null || true
amixer -q -c "$CARD" cset name='Speaker Driver CH3' 200 2>/dev/null || true
amixer -q -c "$CARD" cset name='Speaker Driver CH4' 0 2>/dev/null || true
amixer -q -c "$CARD" cset name='Auto Diagnostics' off 2>/dev/null || true

log "OK: ALSA card $CARD — CH1=0 CH2=200 CH3=200 CH4=0, Auto Diagnostics off"
exit 0
