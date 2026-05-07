#!/bin/bash
# DT510 — TI TAA5412-Q1 (PCM6240 family) smoke checks.
# Run on the target. Exit 0 if I2C + ALSA card look good; non‑zero if broken.
# dmesg: under kernel.dmesg_restrict, use sudo — factory fio can sudo on DT510 (sudo -n if NOPASSWD).
#
# Firmware: snd_soc_pcm6240 requests (see driver) either:
#   - <ti,name-prefix>.bin if the codec node has a name-prefix property, or
#   - taa5412-i2c-<adapter>-<ndev>dev.bin with ndev=1 for a single I2C address.
# On DT510, &i2c2 is usually Linux adapter **1** and reg 0x51 → expect:
#   meta-dynamicdevices-bsp/recipes-kernel/linux/.../lib/firmware/taa5412-i2c-1-1dev.bin
# (ship via linux-firmware / own recipe — not in this repo by default).
#
# Related: meta-dynamicdevices-bsp/docs/DT510-HARDWARE-AUDIT-CHECKLIST.md (TAA5412 + micfil).

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

# --- Kernel module ---
if ! lsmod | grep -q '^snd_soc_pcm6240'; then
	warn "snd_soc_pcm6240 not loaded. Try: modprobe snd_soc_pcm6240"
fi

# --- Firmware on disk (optional but usually required for pcm6240 probe) ---
shopt -s nullglob
FW=(/lib/firmware/taa5412*.bin)
shopt -u nullglob
if [ ${#FW[@]} -eq 0 ]; then
	warn "No /lib/firmware/taa5412*.bin — capture may fail until TI register-block FW is installed."
else
	for f in "${FW[@]}"; do echo "FW: $f"; done
fi

# --- ALSA card from simple-audio-card,name ---
if [ ! -r /proc/asound/cards ]; then
	err "/proc/asound/cards missing"
else
	if grep -q 'taa5412-codec' /proc/asound/cards; then
		echo "ALSA:"
		grep 'taa5412-codec' /proc/asound/cards
		CARD_ID=$(awk '/\[taa5412-codec\]/ {print $1; exit}' /proc/asound/cards)
		if [ -n "$CARD_ID" ]; then
			echo "Card index: $CARD_ID"
			echo "--- arecord -l (taa5412) ---"
			arecord -l 2>/dev/null | grep -A2 "card $CARD_ID:" || arecord -l
			# Short capture: driver accepts 44.1 / 48 kHz (see pcm6240 hw_params).
			OUT=/tmp/taa5412-smoke.wav
			rm -f "$OUT"
			if arecord -D "plughw:${CARD_ID},0" -c2 -r48000 -fS16_LE -d2 "$OUT" 2>/tmp/taa5412-arecord.err; then
				if [ -s "$OUT" ]; then
					echo "Capture OK: wrote $OUT ($(wc -c <"$OUT") bytes)"
				else
					err "arecord succeeded but $OUT is empty"
				fi
			else
				err "arecord failed — see /tmp/taa5412-arecord.err"
				cat /tmp/taa5412-arecord.err >&2 || true
			fi
		else
			err "Could not parse card index for taa5412-codec"
		fi
	else
		err "No ALSA card 'taa5412-codec' in /proc/asound/cards (sound card not bound — check dmesg, micfil disabled, FW)."
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
