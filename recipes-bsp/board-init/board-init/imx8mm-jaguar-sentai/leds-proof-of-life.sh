#!/bin/sh
#
# Orange round-robin loading animation on LEDs (led0..led5).
# One LED lit at a time, cycling for a "loading" effect.
#

ORANGE="255 165 0"
NUM_LEDS=6

# Run until board-init is considered done (optional: run forever with while true)
while true
do
  x=0
  while [ $x -lt $NUM_LEDS ]
  do
    # Turn off all LEDs
    i=0
    while [ $i -lt $NUM_LEDS ]
    do
      path="/sys/class/leds/led${i}"
      [ -d "$path" ] && echo 0 > "$path/brightness" 2>/dev/null || true
      i=$(( i + 1 ))
    done
    # Light current LED orange
    path="/sys/class/leds/led${x}"
    if [ -d "$path" ]; then
      echo "$ORANGE" > "$path/multi_intensity" 2>/dev/null || true
      echo 255 > "$path/brightness" 2>/dev/null || true
    fi
    x=$(( x + 1 ))
    sleep 0.12
  done
done
