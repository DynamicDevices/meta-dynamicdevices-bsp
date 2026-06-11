#!/bin/bash
#
# DT510 (i.MX8MM Jaguar DT510) production test — manufacturing line.
# Invoked via /usr/sbin/production-test.sh (machine dispatcher).
#
#  sudo production-test.sh [--ignore-container-errors]
#
set -euo pipefail

VERSION=0.1
IGNORE_CONTAINER_ERRORS=0
BSP_SHARE="${BOARD_SCRIPTS_SHARE:-/usr/share/board-scripts}"
PING_TARGET="${PRODUCTION_TEST_PING_TARGET:-8.8.8.8}"
WIFI_CON="${PRODUCTION_TEST_WIFI_CON:-VixProduction}"
PLAY_WAV="${BSP_SHARE}/board-testing-now-starting-up-stereo-48k.wav"
DONE_WAV="${BSP_SHARE}/tests-all-completed-stereo-48k.wav"
FALLBACK_WAV="/usr/share/sounds/alsa/Front_Left.wav"
LOG=""

while [[ $# -gt 0 ]]; do
	case $1 in
	--ignore-container-errors)
		IGNORE_CONTAINER_ERRORS=1
		shift
		;;
	-h | --help)
		echo "Usage: production-test.sh [--ignore-container-errors]"
		exit 0
		;;
	*)
		echo "Unknown option: $1" >&2
		exit 1
		;;
	esac
done

fail() {
	echo "TEST FAILED: $*" >&2
	exit 1
}

confirm_yes() {
	local prompt=$1
	local response
	read -r -p "${prompt} [y/N] " response
	[[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]] || fail "operator declined: ${prompt}"
}

step_optional() {
	local prompt=$1
	local response
	read -r -p "${prompt} [y/N] " response
	[[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
}

init_log() {
	local log_dir="/var/log"
	LOG="${log_dir}/production-test-$(date +%Y%m%d-%H%M%S).log"
	: >"$LOG"
	exec > >(tee -a "$LOG") 2>&1
	echo "Production test log: $LOG"
}

require_root() {
	[ "$EUID" -eq 0 ] || fail "run as root: sudo production-test.sh"
}

playback_wav() {
	local wav=$1
	local dev=${2:-default}
	if [ ! -f "$wav" ]; then
		wav=$FALLBACK_WAV
	fi
	[ -f "$wav" ] || fail "no playback WAV (tried ${BSP_SHARE} and ${FALLBACK_WAV})"
	aplay -q -D "$dev" "$wav"
}

stop_vix_apps() {
	echo "Stopping vix-apps containers (Foundries registration check)..."
	local names failed=0
	names=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E '^vix-apps-' || true)
	if [ -z "$names" ]; then
		if [ "$IGNORE_CONTAINER_ERRORS" -eq 1 ]; then
			echo "DEBUG: no vix-apps containers running (--ignore-container-errors)"
			return 0
		fi
		fail "no vix-apps containers running — unit may not have registered with Foundries"
	fi
	for n in $names; do
		if [ "$IGNORE_CONTAINER_ERRORS" -eq 1 ]; then
			docker stop "$n" 2>/dev/null || true
		else
			docker stop "$n" || failed=1
		fi
	done
	if [ "$failed" -ne 0 ]; then
		fail "failed to stop vix-apps containers — use --ignore-container-errors to debug"
	fi
}

ensure_cp2108_nvm() {
	command -v cp2108-get-portconfig >/dev/null 2>&1 || {
		echo "(2) CP2108 NVM — skipped (cp2108-usb-serial tools not installed)"
		return 0
	}
	if cp2108-get-portconfig --quiet-text 2>/dev/null | grep -qE 'EnhancedFxn_IFC[23].*raw=0x0c'; then
		echo "(2) CP2108 NVM already programmed (IFC2/3 = 0x0c)"
		return 0
	fi
	echo "(2) CP2108 NVM needs programming for RS-485 (IFC2/3 → 0x0c)"
	if ! step_optional "Program CP2108 NVM now?"; then
		fail "CP2108 NVM not programmed"
	fi
	cp2108-get-portconfig >"/tmp/cp2108-nvm-before.txt" || true
	cp2108-set-portconfig --rs485-de-invert -y --bus-reset
	cp2108-get-portconfig --quiet-text | grep -E '^--- IFC|raw=' || true
	confirm_yes "Did CP2108 programming complete successfully?"
}

test_dio_loopback() {
	command -v dt510-dio-toggle-outputs >/dev/null 2>&1 || {
		echo "(3) DIO loopback — skipped (dt510-digital-io scripts not installed)"
		return 0
	}
	if ! step_optional "(3) Run DIO loopback test (fixture DO↔DI)?"; then
		fail "DIO test skipped by operator"
	fi
	echo "Ensure DO1–DO4 ↔ DI1–DI4 loopback fixture is connected."
	local s1 s2
	dt510-dio-toggle-outputs 10 25 &
	local tpid=$!
	sleep 0.5
	s1=$(dt510-dio-poll-inputs --once 2>/dev/null | tail -1 || true)
	sleep 0.6
	s2=$(dt510-dio-poll-inputs --once 2>/dev/null | tail -1 || true)
	wait "$tpid" 2>/dev/null || true
	echo "DI sample 1: ${s1:-?}"
	echo "DI sample 2: ${s2:-?}"
	if [ -n "$s1" ] && [ -n "$s2" ] && [ "$s1" = "$s2" ]; then
		echo "WARNING: DI lines did not change during DO toggle — check loopback wiring"
	fi
	confirm_yes "Did DI inputs follow DO toggle on the loopback fixture?"
}

driver_speaker_test() {
	local mixer=drivers dev=driver_speaker
	amixer -q -D "$mixer" cset name='ASI1 Sel' 1 2>/dev/null || true
	amixer -q -D "$mixer" cset name='Digital Volume Control' 100
	amixer -q -D "$mixer" cset name='Amp Gain Volume' 20
	timeout 1 aplay -q -D "$dev" -f S16_LE -r 48000 -c 2 -t raw /dev/zero 2>/dev/null || true
	playback_wav "$PLAY_WAV" "$dev"
	confirm_yes "Did you hear audio on the DRIVER cab speaker?"
}

tannoy_test() {
	local mixer=tannoys dev=tannoy_both_mono ch
	for n in 1 2 3 4; do
		for ch in "Tannoy CH${n}" "Speaker Driver CH${n}"; do
			if amixer -D "$mixer" sset "$ch" -- -17.5dB 2>/dev/null; then
				break
			fi
		done
	done
	playback_wav "$PLAY_WAV" "$dev"
	confirm_yes "Did you hear audio on the PASSENGER tannoy horns?"
}

driver_mic_test() {
	local rec=/tmp/dt510-prod-mic.wav
	if ! step_optional "Record 5s on driver_mic and play back on driver_speaker?"; then
		fail "driver mic test skipped"
	fi
	read -r -p "Press RETURN and speak toward the driver mic..."
	arecord -q -D driver_mic -f S16_LE -r 48000 -c 2 -d 5 "$rec"
	playback_wav "$rec" driver_speaker
	rm -f "$rec"
	confirm_yes "Did you hear the driver mic recording on the driver speaker?"
}

cabin_loop_test() {
	if ! step_optional "Play and record on cabin audio loop (audio_loop / aux)?"; then
		echo "Cabin loop sub-step skipped by operator"
		return 0
	fi
	playback_wav "$FALLBACK_WAV" audio_loop
	confirm_yes "Did you hear audio on the cabin loop (audio_loop)?"
	local rec=/tmp/dt510-prod-loop.wav
	read -r -p "Press RETURN and play audio into the cabin loop input..."
	arecord -q -D aux -f S16_LE -r 48000 -c 2 -d 5 "$rec" || arecord -q -D audio_loop -f S16_LE -r 48000 -c 2 -d 5 "$rec"
	playback_wav "$rec" driver_speaker
	rm -f "$rec"
	confirm_yes "Did you hear the cabin loop recording?"
}

test_audio() {
	if ! step_optional "(4) Perform audio testing?"; then
		fail "audio testing skipped"
	fi
	driver_speaker_test
	tannoy_test
	driver_mic_test
	cabin_loop_test
}

test_wifi() {
	if ! step_optional "(5) Connect to factory Wi-Fi (${WIFI_CON})?"; then
		fail "Wi-Fi test skipped"
	fi
	nmcli con up "$WIFI_CON" || fail "nmcli con up ${WIFI_CON} failed"
	local n=0
	while [ "$n" -lt 30 ]; do
		if nmcli -t -f ACTIVE,SSID dev wifi | grep -q "^yes:${WIFI_CON}$"; then
			break
		fi
		sleep 1
		n=$((n + 1))
	done
	nmcli dev wifi list | head -5 || true
	ping -c 3 -W 5 "$PING_TARGET" || fail "ping ${PING_TARGET} via Wi-Fi failed"
	confirm_yes "Did Wi-Fi associate to ${WIFI_CON} and ping succeed?"
}

test_ethernet() {
	if ! step_optional "(6) Run Ethernet link and ping?"; then
		fail "Ethernet test skipped"
	fi
	ip link set eth0 up 2>/dev/null || true
	local n=0
	while [ "$n" -lt 20 ]; do
		if ip link show eth0 2>/dev/null | grep -q 'state UP'; then
			if [ -n "$(ethtool eth0 2>/dev/null | grep 'Link detected: yes')" ] ||
				ip link show eth0 | grep -q 'LOWER_UP'; then
				break
			fi
		fi
		sleep 1
		n=$((n + 1))
	done
	ping -c 3 -W 5 -I eth0 "$PING_TARGET" || ping -c 3 -W 5 "$PING_TARGET" ||
		fail "ping ${PING_TARGET} via eth0 failed"
	confirm_yes "Did Ethernet link up and ping succeed?"
}

test_ble() {
	if ! step_optional "(7) Perform Bluetooth BLE scan?"; then
		fail "BLE test skipped"
	fi
	bluetoothctl power on
	bluetoothctl --timeout 10 scan on
	bluetoothctl power off
	confirm_yes "Did you see BLE device names or MAC addresses?"
}

test_rs485_loopback() {
	if [ ! -e /dev/etm ]; then
		fail "/dev/etm missing (CP2108 / udev not ready)"
	fi
	if ! step_optional "(8) Run RS-485 loopback on /dev/etm (9600 8O1)?"; then
		fail "RS-485 test skipped"
	fi
	local baud=9600
	stty -F /dev/etm "$baud" cs8 -cstopb parenb -parodd raw -echo min 0 time 10
	local tx_hex="a55a"
	echo "TX ${tx_hex} on /dev/etm..."
	local rx
	rx=$( ( printf '%b' "\\xA5\\x5A" > /dev/etm ) &
		sleep 0.2
		timeout 2 dd if=/dev/etm bs=1 count=2 2>/dev/null | hexdump -v -e '2/1 "%02x"' || true )
	wait || true
	echo "RX: ${rx:-<none>}"
	if [ "$rx" != "a55a" ]; then
		echo "WARNING: expected loopback a55a, got '${rx:-empty}'"
	fi
	if command -v rs485_tx_bytes >/dev/null 2>&1; then
		rs485_tx_bytes --tty /dev/etm --baud "$baud" --hex "01020304" || true
	fi
	confirm_yes "Did RS-485 loopback on /dev/etm pass (fixture connected)?"
}

test_can_loopback() {
	if ! ip link show can0 >/dev/null 2>&1; then
		fail "can0 interface missing"
	fi
	if ! step_optional "(9) Run CAN loopback on can0 (500 kbit/s)?"; then
		fail "CAN test skipped"
	fi
	ip link set can0 down 2>/dev/null || true
	ip link set can0 up type can bitrate 500000 loopback on ||
		ip link set can0 up type can bitrate 500000 ||
		fail "cannot bring can0 up"
	if command -v cansend >/dev/null 2>&1 && command -v candump >/dev/null 2>&1; then
		cansend can0 123#DEADBEEF
		if ! timeout 3 candump can0 -n 1; then
			fail "candump saw no frame on can0"
		fi
	else
		echo "can-utils not installed — checking can0 is UP only"
		ip link show can0 | grep -q 'state UP' || fail "can0 not UP"
	fi
	confirm_yes "Did CAN loopback test pass?"
}

test_gnss() {
	if ! step_optional "(10) Run GNSS NMEA check on /dev/gnss?"; then
		fail "GNSS test skipped"
	fi
	[ -e /dev/gnss ] || fail "/dev/gnss missing"
	if command -v dt510-gnss-reset-pulse >/dev/null 2>&1; then
		dt510-gnss-reset-pulse
	fi
	stty -F /dev/gnss 38400 raw -echo min 0 time 20 2>/dev/null || true
	local n=0 bytes=0
	while [ "$n" -lt 15 ]; do
		bytes=$(timeout 2 dd if=/dev/gnss bs=1 count=64 2>/dev/null | wc -c)
		[ "${bytes// /}" -gt 0 ] && break
		sleep 1
		n=$((n + 1))
	done
	echo "GNSS bytes received: ${bytes// /}"
	[ "${bytes// /}" -gt 0 ] || fail "no NMEA data on /dev/gnss (fix not required)"
	confirm_yes "Did GNSS return NMEA data (valid fix not required)?"
}

test_modem() {
	if ! step_optional "(11) Run cellular modem data ping?"; then
		fail "modem test skipped"
	fi
	command -v mmcli >/dev/null 2>&1 || fail "mmcli not found (ModemManager)"
	local modem_id
	modem_id=$(mmcli -L 2>/dev/null | sed -n 's|.*/Modem/\([0-9]*\).*|\1|p' | head -1)
	[ -n "$modem_id" ] || fail "no modem reported by mmcli -L"
	echo "Modem /Modem/${modem_id}:"
	mmcli -m "$modem_id" || true
	mmcli -m "$modem_id" --enable 2>/dev/null || true
	sleep 3
	mmcli -m "$modem_id" --simple-connect="apn=auto" 2>/dev/null || true
	local n=0
	while [ "$n" -lt 45 ]; do
		if mmcli -m "$modem_id" 2>/dev/null | grep -qiE 'state.*connected|state.*registered'; then
			break
		fi
		sleep 2
		n=$((n + 2))
	done
	ping -c 3 -W 10 "$PING_TARGET" || fail "ping ${PING_TARGET} via cellular failed"
	confirm_yes "Did cellular data ping ${PING_TARGET} succeed?"
}

secure_device() {
	echo
	read -r -p "(12) Secure the device? NOTE YOU CAN ONLY DO THIS ONCE [y/N] " response
	if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		echo SECURING DEVICE
		set-fio-passwd.sh
		rm -f /etc/salt
		enable-firewall.sh
	else
		echo "Skipping secure step (operator declined)"
	fi
}

main() {
	require_root
	init_log
	echo "Running DT510 Production Test - Version ${VERSION}"
	stop_vix_apps
	echo "(1) Board information"
	board-info.sh
	ensure_cp2108_nvm
	test_dio_loopback
	test_audio
	test_wifi
	test_ethernet
	test_ble
	test_rs485_loopback
	test_can_loopback
	test_gnss
	test_modem
	secure_device
	echo "Production test successful"
	date >/etc/.production-test-successful
	playback_wav "$DONE_WAV" driver_speaker || playback_wav "$DONE_WAV" default
	echo "Log saved: $LOG"
	exit 0
}

main "$@"
