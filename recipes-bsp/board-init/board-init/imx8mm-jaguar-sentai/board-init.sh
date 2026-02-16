#!/bin/sh

# Make sure /tmp/presence FIFO is created before anything else happens
# as otherwise it's possible the containers start up and then error as
# they are trying to mount a non-existent folder
mkfifo -m666 /tmp/presence || 1

# Show some life to the user

for x in 0 1 2 3 4 5
do
  path="/sys/class/leds/led${x}"
  echo "255" > $path/brightness
  echo "255 165 0" > $path/multi_intensity
  sleep 0.001
done
