#!/bin/sh
# Load LP50xx LED module and turn on LEDs (orange) for early power-on feedback.
# Run by load-leds-lp50xx-early.service; no udev rule needed.

/sbin/modprobe leds-lp50xx 2>/dev/null || true

ORANGE="255 165 0"
for i in 0 1 2 3 4; do
  p="/sys/class/leds/led$i"
  [ ! -d "$p" ] && continue
  echo 255 > "$p/brightness" 2>/dev/null || true
  [ -f "$p/multi_intensity" ] && echo "$ORANGE" > "$p/multi_intensity" 2>/dev/null || true
done
