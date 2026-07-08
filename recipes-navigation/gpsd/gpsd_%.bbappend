# DT510 carries u-blox NEO-M9V NMEA on /dev/gnss (CP2102N). NDTR and other
# apps open that TTY directly. Installing gpsd for ubxtool/cgps/gpsmon must
# NOT auto-claim the port via systemd socket or USB hotplug udev rules.
#
# OE package names (not Debian): ubxtool is in gps-utils-python (pulls gpsd).
# Debian docs that say IMAGE_INSTALL "gpsd-clients" map here to gps-utils +
# gps-utils-python.

SYSTEMD_AUTO_ENABLE = "disable"
RRECOMMENDS:${PN}:remove = "gpsd-udev"
