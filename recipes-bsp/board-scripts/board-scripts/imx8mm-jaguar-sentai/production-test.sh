#!/bin/bash
set -e

#
# Sentai Initial Production Test.
# Invoked via /usr/sbin/production-test.sh (machine dispatcher).
# To be operated by technician at manufacturing house.
#
#  sudo production-test.sh [--ignore-container-errors]
#

VERSION=0.1
IGNORE_CONTAINER_ERRORS=0

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
		echo "Unknown option: $1"
		exit 1
		;;
	esac
done

if [ "$EUID" -ne 0 ]; then
	echo "Please run as root: sudo production-test.sh"
	exit 1
fi

echo -e "Stopping Sentai application\n"
if [ "$IGNORE_CONTAINER_ERRORS" -eq 1 ]; then
	docker stop sentaispeaker-SentaiSpeaker-1 2>/dev/null || true
	echo "DEBUG: Ignoring container stop errors (--ignore-container-errors flag set)"
else
	if ! docker stop sentaispeaker-SentaiSpeaker-1 2>/dev/null; then
		echo "ERROR: Failed to stop Sentai container 'sentaispeaker-SentaiSpeaker-1'"
		echo "This indicates the unit may not have registered with the Foundries platform."
		echo "Use --ignore-container-errors to debug."
		exit 1
	fi
fi

echo -e "Running Sentai Production Test - Version ${VERSION}\n"

echo -e "(1) Record the board information for your records"
board-info.sh

echo -e "\n"
read -r -p "(2) Run LED tests? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
	echo -e "You should see red, green, blue and white LEDs cycling\n"
	test-leds-hb.sh
	echo -e "\n"
	read -r -p "Did you see the correct LED colours with none missing? [y/N] " response
	if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		echo TEST FAILED
		exit 1
	fi
fi

echo -e "\n"
read -r -p "(3) Run humidity sensor tests? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
	echo -e "\n"
	sensors || true
	echo -e "\n"
	read -r -p "Did a reasonable temperature and humidity value display? [y/N] " response
	if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		echo TEST FAILED
		exit 1
	fi
fi

echo -e "\n"
read -r -p "(4) Program STUSB4500? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
	echo -e "\n"
	stusb4500-utils write --file /lib/firmware/stusb4500.dat
	echo -e "\n"
	read -r -p "Did the programming step complete successfully ? [y/N] " response
	if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		echo TEST FAILED
		exit 1
	fi
fi

echo -e "\n"
read -r -p "(5) Test button input? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
	if [ ! -d /sys/class/gpio/gpio102 ]; then
		echo 102 >/sys/class/gpio/export
	fi
	echo -e "Press and hold down the button within 5s\n"
	sleep 5
	BUTTONVALUE=$(cat /sys/class/gpio/gpio102/value)
	echo -e ">>${BUTTONVALUE}<<\n"
	if [ "${BUTTONVALUE}" -eq "1" ]; then
		echo -e "TEST FAILED - BUTTON PRESS NOT DETECTED\n"
		exit 1
	fi
	echo -e "Button press detected. Release the button now\n"
fi

echo -e "\n"
read -r -p "(6) Perform Audio Testing [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
	echo -e "Setting the audio levels\n\n"
	amixer -c tas2563audio set 'Digital Volume Control' 110
	amixer -c tas2563audio set 'Amp Gain' 20dB
	amixer -c micfilaudio cset name='MICFIL Quality Select' 'High'
	amixer -c micfilaudio set 'CH0' 10
	amixer -c micfilaudio set 'CH1' 10
	for ch in CH2 CH3 CH4 CH5 CH6 CH7; do
		amixer -c micfilaudio set "$ch" 0
	done
	echo -e "Done setting the audio levels\n\n"
	echo -e "Now playing an audio sample\n"
	su -c "aplay -Dhw:1,0 /usr/share/board-scripts/board-testing-now-starting-up-stereo-48k.wav" fio
	read -r -p "Did you hear the audio play back [y/N] " response
	if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		echo TEST FAILED
		exit 1
	fi
	amixer -c micfilaudio set 'CH0' 15
	amixer -c micfilaudio set 'CH1' 0
	echo -e "\n\nNow recording 5s audio on FIRST microphone channel\n"
	read -r -p "Press RETURN key to start recording and then start counting up in a clear voice"
	echo -e "\nStarted recording...\n"
	su -c "arecord -Dhw:2,0 -c2 -f s16_le -r48000 -d5 test-l-stereo.wav && python3 /usr/share/board-scripts/extract_channel.py test-l-stereo.wav test-l.wav 0 && rm -f test-l-stereo.wav" fio
	read -r -p "Done recording. Press RETURN key to play back recording"
	echo -e "\n\nNow playing back recording\n"
	su -c "python3 /usr/share/board-scripts/mono_to_stereo.py test-l.wav test-l-stereo.wav && aplay -Dhw:1,0 test-l-stereo.wav && rm -f test-l.wav test-l-stereo.wav" fio
	read -r -p "Did you hear the audio play back [y/N] " response
	if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		echo TEST FAILED
		exit 1
	fi
	amixer -c micfilaudio set 'CH0' 0
	amixer -c micfilaudio set 'CH1' 15
	echo -e "\n\nNow recording 5s audio on SECOND microphone channel\n"
	read -r -p "Press RETURN key to start recording and then start counting up in a clear voice"
	echo -e "\nStarted recording...\n"
	su -c "arecord -Dhw:2,0 -c2 -f s16_le -r48000 -d5 test-r-stereo.wav && python3 /usr/share/board-scripts/extract_channel.py test-r-stereo.wav test-r.wav 1 && rm -f test-r-stereo.wav" fio
	read -r -p "Done recording. Press RETURN key to play back recording"
	echo -e "\n\nNow playing back recording\n"
	su -c "python3 /usr/share/board-scripts/mono_to_stereo.py test-r.wav test-r-stereo.wav && aplay -Dhw:1,0 test-r-stereo.wav && rm -f test-r.wav test-r-stereo.wav" fio
	read -r -p "Did you hear the audio play back [y/N] " response
	if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		echo TEST FAILED
		exit 1
	fi
fi

echo -e "\n"
read -r -p "(7) Perform Bluetooth BLE Testing [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
	echo -e "Now scanning for bluetooth devices\n"
	bluetoothctl power on
	bluetoothctl --timeout 5 scan on
	bluetoothctl power off
	echo -e "\n^^^ You should have seen a number of MAC addresses and device names\n"
	read -r -p "Did you see a number of bluetooth MAC addresses and device names ? [y/N] " response
	if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		echo TEST FAILED
		exit 1
	fi
fi

echo -e "\n"
read -r -p "(8) Perform Radar Testing [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
	echo -e "Checking radar service status...\n"
	if ! systemctl is-active --quiet xm125-radar-monitor.service; then
		echo "TEST FAILED - xm125-radar-monitor service is not running"
		systemctl status xm125-radar-monitor.service --no-pager -l || true
		exit 1
	fi
	if [ ! -p /tmp/presence ]; then
		echo "TEST FAILED - /tmp/presence FIFO does not exist"
		exit 1
	fi
	echo -e "IMPORTANT: You must be present in front of the sensor for this test\n"
	PRESENCE_DETECTED=0
	PRESENCE_DATA=""
	START_TIME=$(date +%s)
	TIMEOUT=60
	while [ $(($(date +%s) - START_TIME)) -lt "$TIMEOUT" ]; do
		READ_DATA=$(timeout 1 cat /tmp/presence 2>&1) || true
		if [ -n "$READ_DATA" ] && ! echo "$READ_DATA" | grep -q "timeout: cannot run command"; then
			PRESENCE_DATA="$READ_DATA"
			if echo "$PRESENCE_DATA" | grep -q '"presence_detected":true'; then
				PRESENCE_DETECTED=1
				echo -e "Presence detected - sensor is working\n"
				break
			fi
		fi
		sleep 1
	done
	if [ "$PRESENCE_DETECTED" -eq 0 ]; then
		echo "TEST FAILED - No presence detected after ${TIMEOUT} seconds."
		exit 1
	fi
	echo -e "Please cover the radar sensor with your hand or an object\n"
	read -r -p "Press RETURN when you have covered the sensor..."
	NO_PRESENCE_CONFIRMED=0
	START_TIME=$(date +%s)
	while [ $(($(date +%s) - START_TIME)) -lt "$TIMEOUT" ]; do
		READ_DATA=$(timeout 1 cat /tmp/presence 2>&1) || true
		if [ -n "$READ_DATA" ] && echo "$READ_DATA" | grep -q '"presence_detected":false'; then
			NO_PRESENCE_CONFIRMED=1
			echo -e "No presence detected - sensor correctly detected coverage\n"
			break
		fi
		sleep 1
	done
	if [ "$NO_PRESENCE_CONFIRMED" -eq 0 ]; then
		echo "TEST FAILED - Sensor still detecting presence when covered"
		exit 1
	fi
fi

echo -e "\n"
read -r -p "(9) Are you ready to secure the device? NOTE YOU CAN ONLY DO THIS ONCE [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
	echo SECURING DEVICE
	set-fio-passwd.sh
	rm -f /etc/salt
	enable-firewall.sh
fi

echo -e "Production test successful\n"
date >/etc/.production-test-successful
su -c "aplay -Dhw:1,0 /usr/share/board-scripts/tests-all-completed-stereo-48k.wav" fio
exit 0
