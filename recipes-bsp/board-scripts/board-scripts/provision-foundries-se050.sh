#!/bin/bash
#
# DT510 manufacturing: provision NXP SE050 for Foundries device registration (HSM)
# and aktualizr-lite PKCS#11 (libckteec → OpTEE → SE050).
#
# Run once per unit BEFORE network / lmp-device-auto-register (production-test step 4b).
#
# PINs MUST NOT be baked into this script. Supply via factory station:
#   - /run/factory/se050-pins.env  (HSM_PIN=… HSM_SOPIN=…)
#   - or environment SE050_HSM_PIN + SE050_HSM_SOPIN
#
# Bench/dev only: ALLOW_SE050_DEV_PINS=1 uses Foundries doc example PINs (never on production line).
#
set -euo pipefail

HSM_CONFIG=/etc/sota/hsm
MARKER=/var/sota/se050-foundries-provisioned
PIN_ENV_FILE="${SE050_PIN_ENV_FILE:-/run/factory/se050-pins.env}"
PKCS11_MODULE="${PKCS11_MODULE:-}"
TOKEN_LABEL="${SE050_TOKEN_LABEL:-aktualizr}"
KEY_ID="${SE050_KEY_ID:-01}"
KEY_LABEL="${SE050_KEY_LABEL:-foundries-device-key}"
KEY_TYPE="${SE050_KEY_TYPE:-RSA:2048}"

fail() {
	echo "provision-foundries-se050: ERROR: $*" >&2
	exit 1
}

require_root() {
	[ "${EUID:-$(id -u)}" -eq 0 ] || fail "run as root (sudo provision-foundries-se050.sh)"
}

find_pkcs11_module() {
	local m
	for m in /usr/lib/libckteec.so.0 /usr/lib/libckteec.so.0.1 /usr/lib/libckteec.so; do
		if [ -f "$m" ]; then
			echo "$m"
			return 0
		fi
	done
	return 1
}

ensure_tee_supplicant() {
	if pgrep -x tee-supplicant >/dev/null 2>&1; then
		return 0
	fi
	if command -v systemctl >/dev/null 2>&1; then
		for unit in tee-supplicant@teepriv0.service tee-supplicant@tee0.service tee-supplicant.service; do
			if systemctl cat "$unit" >/dev/null 2>&1; then
				systemctl start "$unit" 2>/dev/null && break
			fi
		done
	fi
	if ! pgrep -x tee-supplicant >/dev/null 2>&1; then
		if [ -c /dev/teepriv0 ]; then
			tee-supplicant -d /dev/teepriv0 &
		elif [ -c /dev/tee0 ]; then
			tee-supplicant -d /dev/tee0 &
		fi
	fi
	sleep 1
	pgrep -x tee-supplicant >/dev/null 2>&1 ||
		fail "tee-supplicant not running — check OpTEE / se05x image (see DT510-SE050.md)"
}

load_pins() {
	if [ -f "$PIN_ENV_FILE" ]; then
		# shellcheck disable=SC1090
		. "$PIN_ENV_FILE"
	fi
	HSM_PIN="${HSM_PIN:-${SE050_HSM_PIN:-}}"
	HSM_SOPIN="${HSM_SOPIN:-${SE050_HSM_SOPIN:-}}"

	if [ -n "$HSM_PIN" ] && [ -n "$HSM_SOPIN" ]; then
		return 0
	fi

	if [ "${ALLOW_SE050_DEV_PINS:-0}" = "1" ]; then
		echo "WARNING: using Foundries documentation example PINs (ALLOW_SE050_DEV_PINS=1)"
		HSM_PIN="${HSM_PIN:-87654321}"
		HSM_SOPIN="${HSM_SOPIN:-12345678}"
		return 0
	fi

	fail "missing HSM PINs — create ${PIN_ENV_FILE} with HSM_PIN and HSM_SOPIN, or export SE050_HSM_PIN / SE050_HSM_SOPIN (see DT510-SE050.md)"
}

write_hsm_config() {
	install -d -m 0750 /etc/sota
	cat >"$HSM_CONFIG" <<EOF
# Written by provision-foundries-se050.sh — do not commit real PINs to git.
HSM_MODULE="${PKCS11_MODULE}"
HSM_PIN="${HSM_PIN}"
HSM_SOPIN="${HSM_SOPIN}"
EOF
	chmod 0600 "$HSM_CONFIG"
}

token_has_objects() {
	pkcs11-tool --module "$PKCS11_MODULE" --token-label "$TOKEN_LABEL" \
		--pin "$HSM_PIN" --list-objects 2>/dev/null | grep -q .
}

slot_initialized() {
	pkcs11-tool --module "$PKCS11_MODULE" --list-token-slots 2>/dev/null |
		grep -qi "$TOKEN_LABEL"
}

init_token_if_needed() {
	if slot_initialized && token_has_objects; then
		echo "PKCS#11 token '${TOKEN_LABEL}' already has objects — skipping init/keygen"
		return 0
	fi

	if ! slot_initialized; then
		echo "Initializing PKCS#11 token label '${TOKEN_LABEL}' on SE050…"
		pkcs11-tool --module "$PKCS11_MODULE" \
			--init-token --label "$TOKEN_LABEL" \
			--so-pin "$HSM_SOPIN" --pin "$HSM_PIN"
	fi

	if token_has_objects; then
		return 0
	fi

	echo "Generating device key (${KEY_TYPE}, id=${KEY_ID}) on token '${TOKEN_LABEL}'…"
	pkcs11-tool --module "$PKCS11_MODULE" \
		--token-label "$TOKEN_LABEL" --pin "$HSM_PIN" \
		--keypairgen --key-type "$KEY_TYPE" --id "$KEY_ID" --label "$KEY_LABEL"
}

verify_provision() {
	pkcs11-tool --module "$PKCS11_MODULE" --list-token-slots
	pkcs11-tool --module "$PKCS11_MODULE" --token-label "$TOKEN_LABEL" \
		--pin "$HSM_PIN" --list-objects
	[ -f "$HSM_CONFIG" ] || fail "missing ${HSM_CONFIG}"
	grep -q "^HSM_MODULE=" "$HSM_CONFIG" || fail "invalid ${HSM_CONFIG}"
	if command -v fio-se05x-cli >/dev/null 2>&1; then
		fio-se05x-cli --list-objects all --se050 2>/dev/null | head -20 || true
	fi
	echo "SE050 Foundries provision OK — ${HSM_CONFIG} ready for lmp-device-auto-register"
}

main() {
	require_root
	PKCS11_MODULE="${PKCS11_MODULE:-$(find_pkcs11_module || fail "libckteec not found — factory image needs se05x / lmp-feature-se05x")}"

	if [ -f "$MARKER" ] && [ -f "$HSM_CONFIG" ]; then
		echo "Already provisioned ($MARKER) — verifying only"
		# shellcheck disable=SC1090
		[ -f "$HSM_CONFIG" ] && . "$HSM_CONFIG"
		HSM_PIN="${HSM_PIN:-}"
		[ -n "$HSM_PIN" ] || fail "re-verify needs PIN in ${HSM_CONFIG}"
		ensure_tee_supplicant
		verify_provision
		exit 0
	fi

	if [ -f /var/sota/sql.db ]; then
		fail "device already registered (/var/sota/sql.db) — SE050 HSM provision must run before first Foundries registration"
	fi

	command -v pkcs11-tool >/dev/null 2>&1 || fail "pkcs11-tool not installed (se05x factory image?)"

	load_pins
	ensure_tee_supplicant

	echo "Using PKCS#11 module: ${PKCS11_MODULE}"
	pkcs11-tool --module "$PKCS11_MODULE" --list-token-slots || fail "cannot list PKCS#11 slots"

	init_token_if_needed
	write_hsm_config
	install -d -m 0750 /var/sota
	date -Iseconds >"$MARKER"
	chmod 0640 "$MARKER"

	verify_provision
}

main "$@"
