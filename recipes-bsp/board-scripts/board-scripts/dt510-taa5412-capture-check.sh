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

_read_pasitx_regs() {
	local _pas _pas2
	_pas=""
	_pas2=""
	local regmap="/sys/kernel/debug/regmap/1-0051/registers"
	local i2c_bus=1 i2c_addr=0x51
	if [ -r "$regmap" ]; then
		_pas=$(grep -E '^001e:' "$regmap" 2>/dev/null | awk '{print $2}')
		_pas2=$(grep -E '^001f:' "$regmap" 2>/dev/null | awk '{print $2}')
	fi
	if command -v i2cget >/dev/null 2>&1; then
		i2cset -f -y "$i2c_bus" "$i2c_addr" 0x00 0x00 b 2>/dev/null || true
		_pas=$(i2cget -f -y "$i2c_bus" "$i2c_addr" 0x1e b 2>/dev/null | sed 's/0x//')
		_pas2=$(i2cget -f -y "$i2c_bus" "$i2c_addr" 0x1f b 2>/dev/null | sed 's/0x//')
	fi
	PASITX1="$_pas"
	PASITX2="$_pas2"
}

# Peak abs sample value from WAV data after skip_sec (S16_LE stereo @ 48 kHz).
_wav_peak_after_sec() {
	local wav=$1 skip_sec=${2:-1}
	local rate=48000 ch=2 bps=2
	local skip=$((44 + skip_sec * rate * ch * bps))
	[ -s "$wav" ] || { echo 0; return; }
	od -An -td2 -j "$skip" "$wav" 2>/dev/null | awk '
		function abs(x) { return x < 0 ? -x : x }
		{ for (i = 1; i <= NF; i++) { a = abs($i); if (a > max) max = a } }
		END { print max + 0 }
	'
}

# Run arecord in background; sample PASITX during active capture; analyse WAV.
_capture_with_pasitx() {
	local device=$1 out=$2 errf=$3
	local ar pas_warn=0 wav_peak_ok=0 peak=0
	local pas="" pas2="" hex bit5 hex2 bit5_2

	rm -f "$out" "$errf"
	arecord -D "$device" -fS16_LE -c2 -r48000 -d3 "$out" 2>"$errf" &
	ar=$!

	# Poll PASITX while capture is running (bit5 may only be set during stream).
	local n=0
	while [ "$n" -lt 10 ]; do
		sleep 0.5
		n=$((n + 1))
		if ! kill -0 "$ar" 2>/dev/null; then
			break
		fi
		if [ "$n" -ge 2 ]; then
			_read_pasitx_regs
			pas=$PASITX1
			pas2=$PASITX2
		fi
	done

	if kill -0 "$ar" 2>/dev/null; then
		_read_pasitx_regs
		pas=$PASITX1
		pas2=$PASITX2
	fi

	if ! wait "$ar"; then
		return 1
	fi

	if [ ! -s "$out" ]; then
		err "arecord succeeded but $out is empty"
		return 1
	fi

	echo "Wrote $out ($(wc -c <"$out") bytes)"

	peak=$(_wav_peak_after_sec "$out" 1)
	echo "WAV sec2+ peak=${peak}"
	if [ "$peak" -gt 50 ]; then
		wav_peak_ok=1
		echo "WAV sec2+ non-silent — capture path OK"
	fi

	if [ -z "$pas" ]; then
		if [ "$wav_peak_ok" -eq 0 ]; then
			warn "PASITXCH1: could not read reg 0x1e during capture"
		else
			echo "NOTICE: PASITXCH1 unread during capture; WAV sec2+ peak confirms audio"
		fi
	else
		hex=$((16#$pas))
		bit5=$(( (hex >> 5) & 1 ))
		echo "PASITXCH1 (0x1e)=0x$(printf '%02x' "$hex") during capture — ASI_TX bit5=${bit5}"
		if [ "$bit5" -eq 0 ]; then
			if [ "$wav_peak_ok" -eq 0 ]; then
				warn "PASITXCH1 ASI_TX bit5=0 — codec serial TX path off (see DT510-TAA5412-DRIVER-MIC-ALSA.md)"
			else
				echo "NOTICE: PASITXCH1 bit5=0 but WAV sec2+ peak=${peak} — treating capture as OK"
			fi
		fi
	fi

	if [ -n "$pas2" ]; then
		hex2=$((16#$pas2))
		bit5_2=$(( (hex2 >> 5) & 1 ))
		echo "PASITXCH2 (0x1f)=0x$(printf '%02x' "$hex2") during capture — ASI_TX bit5=${bit5_2} slot=$((hex2 & 0x1f))"
		if [ "$bit5_2" -eq 0 ]; then
			if [ "$wav_peak_ok" -eq 0 ]; then
				warn "PASITXCH2 ASI_TX bit5=0 — ALSA ch1 / IN2 will be silent (pcm6240 needs PASITXCH2=0x30)"
			else
				echo "NOTICE: PASITXCH2 bit5=0 but IN1/WAV OK (peak=${peak}) — ch1 path may still be silent"
			fi
		fi
	fi

	return 0
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
			ERRF=/tmp/taa5412-arecord.err
			ok=0
			if _capture_with_pasitx driver_mic "$OUT" "$ERRF"; then
				echo "Capture via driver_mic OK"
				ok=1
			else
				rm -f "$OUT"
				if _capture_with_pasitx "plughw:${CARD_ID},0" "$OUT" "$ERRF"; then
					echo "Capture via plughw (2ch) OK"
					ok=1
				else
					rm -f "$OUT"
					# 4ch plughw fallback — shorter capture still samples PASITX mid-stream
					arecord -D "plughw:${CARD_ID},0" -c4 -r48000 -fS16_LE -d3 "$OUT" 2>"$ERRF" &
					ar=$!
					sleep 1
					_read_pasitx_regs
					kill "$ar" 2>/dev/null
					wait "$ar" 2>/dev/null || true
					if [ -s "$OUT" ]; then
						echo "Capture via plughw (4ch) OK"
						ok=1
						peak=$(_wav_peak_after_sec "$OUT" 1)
						echo "WAV sec2+ peak=${peak}"
					fi
				fi
			fi
			if [ "$ok" -eq 0 ]; then
				err "arecord failed (driver_mic then plughw) — see $ERRF"
				cat "$ERRF" >&2 || true
			fi
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
