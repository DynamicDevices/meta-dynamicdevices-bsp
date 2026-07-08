# u-blox NEO-M9V GNSS — image gpsd/ubxtool packages from
# meta-dynamicdevices-distro lmp-feature-neo-m9v.inc when MACHINE_FEATURES
# contains `neo-m9v`.
#
# Hardware path (DT510): NEO-M9V UART → CP2102N → /dev/gnss (udev) is independent
# of this feature; enable neo-m9v when the image should ship ubxtool/cgps/gpsmon.

MACHINE_FEATURES_BACKFILL_CONSIDERED:append = " neo-m9v"
