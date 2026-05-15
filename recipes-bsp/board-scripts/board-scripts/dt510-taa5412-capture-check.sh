#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
#
# DT510 — TI TAA5412-Q1 (PCM6240 family) smoke checks.
# Prefers ALSA pcm **driver_mic** (alsa-state asound.conf → Driver Mic); falls back to plughw.
# Exit 0 if I2C + ALSA card look reasonable; non-zero if broken.
#
# Firmware: snd_soc_pcm6240 requests taa5412-i2c-<adapter>-1dev.bin (typ. i2c-1 on DT510).
# Related: meta-dynamicdevices-bsp/docs/DT510-TAA5412-DRIVER-MIC-ALSA.md

shopt -s nullglob

RC=0
warn() { echo "WARN: $*" >&2; RC=1; }
err() { echo "ERR: $*" >&2; RC=1; }

echo "=== TAA5412 / PCM6240 smoke ($(date -Iseconds)) ==="

# --- I2C: DT510 &i2c2 @ 0x51 is typically sysfs 1-0051 (verify if your image differs) ---
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

if ! lsmod | grep -q '^snd_soc_pcm6240'; then
	warn "snd_soc_pcm6240 not loaded. Try: modprobe snd_soc_pcm6240"
fi

FW=(/lib/firmware/taa5412*.bin)
if [ ${#FW[@]} -eq 0 ]; then
	warn "No /lib/firmware/taa5412*.bin — capture may fail until TI register-block FW is installed."
else
	for f in "${FW[@]}"; do echo "FW: $f"; done
fi
shopt -u nullglob

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
			OUT=/tmp/taa5412-smoke.wav
			rm -f "$OUT"
			ERRF=/tmp/taa5412-arecord.err
			ok=0
			if arecord -D driver_mic -c4 -r48000 -fS16_LE -d2 "$OUT" 2>"$ERRF"; then
				echo "Capture via driver_mic OK"
				ok=1
			else
				rm -f "$OUT"
				if arecord -D "plughw:${CARD_ID},0" -c4 -r48000 -fS16_LE -d2 "$OUT" 2>"$ERRF"; then
					echo "Capture via plughw (4ch) OK"
					ok=1
				else
					rm -f "$OUT"
					if arecord -D "plughw:${CARD_ID},0" -c2 -r48000 -fS16_LE -d2 "$OUT" 2>"$ERRF"; then
						echo "Capture via plughw (2ch) OK"
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
				err "arecord failed (driver_mic then plughw 4ch/2ch) — see $ERRF"
				cat "$ERRF" >&2 || true
			fi
		else
			err "Could not parse card index for taa5412-codec"
		fi
	else
		err "No ALSA card 'taa5412-codec' in /proc/asound/cards (probe / dmesg / micfil / FW)."
	fi
fi

echo "--- dmesg (taa5412 / pcm6240 / 0051 / firmware) ---"
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
_dmesg 2>/dev/null | grep -iE 'taa5412|pcm6240|0051|request_firmware|sound-taa5412|simple-card|deferred probe' | tail -30 || true

echo "=== done (exit $RC) ==="
exit "$RC"
