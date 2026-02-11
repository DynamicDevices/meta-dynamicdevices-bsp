#!/bin/sh
# Turn on LED as soon as udev creates the device (run at "power on" visibility).
# Called by udev with LED kernel name (e.g. led0) as first argument.
[ -z "$1" ] && exit 0
path="/sys/class/leds/$1"
[ ! -d "$path" ] && exit 0
echo 255 > "$path/brightness" 2>/dev/null || true
[ -f "$path/multi_intensity" ] && echo "255 165 0" > "$path/multi_intensity" 2>/dev/null || true
