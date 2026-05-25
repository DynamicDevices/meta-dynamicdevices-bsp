#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
#
# DT510 — TI TAA5412-Q1 smoke checks (Path A pcm6240 or Path B tac5x1x-ti OOT).
# Prefers ALSA pcm **driver_mic**; falls back to plughw.
# Exit 0 if I2C + ALSA card look reasonable; non-zero if broken.
#
# Related: meta-dynamicdevices-bsp/docs/DT510-TAA5412-DRIVER-MIC-ALSA.md

shopt -s nullglob

RC=0
warn() { echo "WARN: $*" >&2; RC=1; }
err() { echo "ERR: $*" >&2; RC=1; }

DRIVER_PATH=""
if lsmod | grep -q '^snd_soc_tac5x1x_taa5412'; then
	DRIVER_PATH="oot-tac5x1x"
elif lsmod | grep -q '^snd_soc_pcm6240'; then
	DRIVER_PATH="pcm6240"
fi

echo "=== TAA5412 driver mic smoke ($(date -Iseconds)) driver=${DRIVER_PATH:-unknown} ==="

# --- I2C: DT510 &i2c2 @ 0x51 is typically sysfs 1-0051 ---
I2C_NODE=""
for p in /sys/bus/i2c/devices/*-0051/name; do
	if [ -r "$p" ] && [ "$(tr -d '\r\n' <"$p")" = taa5412 ]; then
		I2C_NODE="${p%/name}"
		echo "I2C OK: $(basename "$I2C_NODE") name=$(cat "$p")"
		break
	fi
done
if [ -z "$I2C_NODE" ]; then
	err "No I2C device *-0051 with name 'taa5412'. Check wiring, DT reg, and i2cdetect."
fi

case "$DRIVER_PATH" in
oot-tac5x1x)
	echo "Driver: snd_soc_tac5x1x_taa5412 (Path B — factory taa5412-tac5x1x-ti)"
	;;
pcm6240)
	echo "Driver: snd_soc_pcm6240 (Path A — taa5412 + firmware blob)"
	FW=(/lib/firmware/taa5412*.bin)
	if [ ${#FW[@]} -eq 0 ]; then
		warn "No /lib/firmware/taa5412*.bin — Path A capture needs TI register-block FW."
	else
		for f in "${FW[@]}"; do echo "FW: $f"; done
	fi
	;;
*)
	warn "Neither snd_soc_tac5x1x_taa5412 nor snd_soc_pcm6240 loaded."
	;;
esac
shopt -u nullglob

_check_pasitx_during_capture() {
	local regmap="/sys/kernel/debug/regmap/1-0051/registers"
	if [ ! -r "$regmap" ]; then
		warn "PASITXCH1: regmap debugfs unavailable (sudo + debugfs) — skip ASI bit check"
		return 0
	fi
	local out errf ar pas hex bit5
	out=/tmp/taa5412-smoke-bg.wav
	errf=/tmp/taa5412-smoke-bg.err
	rm -f "$out"
	arecord -D driver_mic -fS16_LE -c2 -r48000 -d2 "$out" 2>"$errf" &
	ar=$!
	sleep 1
	if ! kill -0 "$ar" 2>/dev/null; then
		warn "PASITXCH1: background arecord exited early — see $errf"
		wait "$ar" 2>/dev/null || true
		return 0
	fi
	pas=$(grep -E '^001e:' "$regmap" 2>/dev/null | awk '{print $2}')
	kill "$ar" 2>/dev/null
	wait "$ar" 2>/dev/null || true
	if [ -z "$pas" ]; then
		warn "PASITXCH1: could not read reg 0x1e from regmap during capture"
		return 0
	fi
	hex=$((16#$pas))
	bit5=$(( (hex >> 5) & 1 ))
	echo "PASITXCH1 (0x1e)=0x$(printf '%02x' "$hex") during capture — ASI_TX bit5=${bit5}"
	if [ "$bit5" -eq 0 ]; then
		warn "PASITXCH1 ASI_TX bit5=0 — codec serial TX path off (DAPM/ASI; see DT510-TAA5412-DRIVER-MIC-ALSA.md)"
	fi
}

if [ ! -r /proc/asound/cards ]; then
	err "/proc/asound/cards missing"
else
	if grep -q 'taa5412-codec' /proc/asound/cards; then
		echo "ALSA:"
		grep 'taa5412-codec' /proc/asound/cards
		CARD_ID=$(awk '/simple-card - taa5412-codec/ {
			sub(/^[[:space:]]+/, "");
			print $1;
			exit
		}' /proc/asound/cards)
		if [ -n "$CARD_ID" ]; then
			echo "Card index: $CARD_ID"
			echo "--- arecord -l (taa5412) ---"
			arecord -l 2>/dev/null | grep -A2 "card $CARD_ID:" || arecord -l
			echo "Note: scope SAI5 only during arecord -D driver_mic — not aplay driver_speaker (SAI3)."
			OUT=/tmp/taa5412-smoke.wav
			rm -f "$OUT"
			ERRF=/tmp/taa5412-arecord.err
			ok=0
			if arecord -D driver_mic -c2 -r48000 -fS16_LE -d2 "$OUT" 2>"$ERRF"; then
				echo "Capture via driver_mic OK"
				ok=1
			else
				rm -f "$OUT"
				if arecord -D "plughw:${CARD_ID},0" -c2 -r48000 -fS16_LE -d2 "$OUT" 2>"$ERRF"; then
					echo "Capture via plughw (2ch) OK"
					ok=1
				else
					rm -f "$OUT"
					if arecord -D "plughw:${CARD_ID},0" -c4 -r48000 -fS16_LE -d2 "$OUT" 2>"$ERRF"; then
						echo "Capture via plughw (4ch) OK"
						ok=1
					fi
				fi
			fi
			if [ "$ok" -eq 1 ]; then
				if [ -s "$OUT" ]; then
					echo "Wrote $OUT ($(wc -c <"$OUT") bytes)"
				else
					err "arecord succeeded but $OUT is empty"
				fi
			else
				err "arecord failed (driver_mic then plughw) — see $ERRF"
				cat "$ERRF" >&2 || true
			fi
			_check_pasitx_during_capture
		else
			err "Could not parse card index for taa5412-codec"
		fi
	else
		err "No ALSA card 'taa5412-codec' in /proc/asound/cards (probe / dmesg / micfil / driver path)."
	fi
fi

echo "--- dmesg (taa5412 / sai5 / deferred) ---"
_dmesg() {
	if dmesg >/dev/null 2>&1; then
		dmesg
	elif sudo -n dmesg >/dev/null 2>&1; then
		sudo -n dmesg
	else
		echo "(no dmesg: run as root, or sudo dmesg, or sudo -n dmesg if fio has NOPASSWD)" >&2
		return 1
	fi
}
_dmesg 2>/dev/null | grep -iE 'taa5412|pcm6240|tac5x1x|0051|request_firmware|sound-taa5412|30050000|sai5|simple-card|deferred probe|invalid binding' | tail -30 || true

echo "=== done (exit $RC) ==="
exit "$RC"
