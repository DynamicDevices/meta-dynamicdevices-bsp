#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# DT510 — Auracast / LE Audio image smoke: confirm stack by **files on the image** (no rpm/opkg).
# Run on the target after flash. See: meta-dynamicdevices-distro/recipes-samples/images/lmp-feature-le-audio.inc
# Tracker: meta-dynamicdevices-bsp/docs/DT510-AURACAST-LE-AUDIO.md

set -uo pipefail
RC=0
fail() { echo "FAIL: $*" >&2; RC=1; }
pass() { echo "OK:  $*"; }
warn() { echo "WARN: $*" >&2; }

need_file() {
	local f="$1"
	local msg="${2:-$1}"
	if [ -f "$f" ] || [ -x "$f" ]; then
		pass "$msg"
	else
		fail "missing: $f"
	fi
}

echo "=== DT510 Auracast / LE Audio image check ($(date -Iseconds)) ==="
uname -a || true
[ -r /etc/os-release ] && head -5 /etc/os-release || true

echo "--- Required paths (userland) ---"
need_file /usr/bin/pipewire
need_file /usr/bin/wireplumber
need_file /usr/bin/bluetoothctl

echo "--- BlueZ daemon (path varies by distro split) ---"
BTD=""
for c in /usr/libexec/bluetooth/bluetoothd /usr/lib/bluetooth/bluetoothd; do
	if [ -x "$c" ]; then
		BTD="$c"
		break
	fi
done
if [ -n "$BTD" ]; then
	pass "bluetoothd at $BTD"
else
	fail "no bluetoothd at /usr/libexec/bluetooth/bluetoothd or /usr/lib/bluetooth/bluetoothd"
fi

echo "--- WirePlumber drop-in (le-audio-wireplumber-config) ---"
WP_CONF="/usr/share/wireplumber/wireplumber.conf.d/51-bluez-imx-le-audio.conf"
need_file "$WP_CONF" "LE Audio WirePlumber fragment"
grep -E 'bap_bcast|bluez5\.roles|lc3' "$WP_CONF" | head -15 || true

echo "--- PipeWire SPA BlueZ5 (LC3 / BAP backend — optional path layout) ---"
SPA_HIT=0
for lib in /usr/lib /usr/lib64; do
	if [ -d "$lib/spa-0.2/bluez5" ]; then
		n="$(find "$lib/spa-0.2/bluez5" -maxdepth 1 -type f 2>/dev/null | wc -l)"
		if [ "${n:-0}" -gt 0 ]; then
			pass "SPA bluez5 plugins under $lib/spa-0.2/bluez5 ($n files)"
			ls -la "$lib/spa-0.2/bluez5" 2>/dev/null | head -12 || true
			SPA_HIT=1
			break
		fi
	fi
done
if [ "$SPA_HIT" -eq 0 ]; then
	warn "no /usr/lib*/spa-0.2/bluez5 with plugin files — layout may differ; inspect /usr/lib*/spa-0.2 and /usr/lib*/pipewire* manually"
fi

echo "--- Versions ---"
for b in pipewire wireplumber bluetoothctl; do
	if command -v "$b" >/dev/null 2>&1; then
		echo -n "$b: "
		"$b" --version 2>&1 | head -1 || true
	fi
done

echo "=== done (exit $RC) ==="
exit "$RC"
