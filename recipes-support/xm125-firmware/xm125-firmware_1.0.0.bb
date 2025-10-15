SUMMARY = "Acconeer XM125 Radar Module Firmware Files"
DESCRIPTION = "Firmware binary files for the Acconeer XM125 radar module. Control utilities are provided by the xm125-radar-monitor package."
HOMEPAGE = "https://developer.acconeer.com/"
LICENSE = "CLOSED"
LIC_FILES_CHKSUM = ""

SECTION = "base"
# No build dependencies - only firmware files
DEPENDS = ""
# Runtime dependencies only for firmware files
RDEPENDS:${PN} = ""

# Version should match the XM125 firmware version
PV = "1.0.0"
PR = "r2"

SRC_URI = " \
    file://README-firmware.md \
    file://i2c_presence_detector.bin \
    file://i2c_distance_detector.bin \
    file://i2c_ref_app_breathing.bin \
"

# Note: Shell scripts and systemd service moved to xm125-radar-monitor package
# The following files are no longer included in this firmware-only package:
# - xm125-control.sh
# - xm125-firmware-flash.sh  
# - xm125-firmware-manager.service
# - test-gpio-commands.sh

# Firmware files - add your actual firmware files here
# SRC_URI += " \
#     file://xm125_firmware_v1.0.0.bin \
#     file://xm125_bootloader_v1.0.0.bin \
# "

S = "${WORKDIR}"

COMPATIBLE_MACHINE = "(imx8mm-jaguar-sentai)"

# Only install if XM125 radar feature is enabled
ALLOW_EMPTY:${PN} = "1"
python () {
    machine_features = d.getVar('MACHINE_FEATURES') or ''
    if 'xm125-radar' not in machine_features:
        raise bb.parse.SkipRecipe("XM125 radar feature not enabled")
}

do_configure[noexec] = "1"
do_compile[noexec] = "1"

do_install() {
    # Install firmware files in /lib/firmware/acconeer/
    install -d ${D}${nonarch_base_libdir}/firmware/acconeer
    install -m 0644 ${WORKDIR}/i2c_presence_detector.bin ${D}${nonarch_base_libdir}/firmware/acconeer/
    install -m 0644 ${WORKDIR}/i2c_distance_detector.bin ${D}${nonarch_base_libdir}/firmware/acconeer/
    install -m 0644 ${WORKDIR}/i2c_ref_app_breathing.bin ${D}${nonarch_base_libdir}/firmware/acconeer/
    
    # Install documentation
    install -d ${D}${docdir}/${PN}
    install -m 0644 ${WORKDIR}/README-firmware.md ${D}${docdir}/${PN}/
}

FILES:${PN} = " \
    ${nonarch_base_libdir}/firmware/acconeer/* \
    ${docdir}/${PN}/* \
"

# No systemd service in firmware-only package
# inherit systemd
# SYSTEMD_SERVICE:${PN} = "xm125-firmware-manager.service"
# SYSTEMD_AUTO_ENABLE:${PN} = "disable"

# Package information
PACKAGE_ARCH = "${MACHINE_ARCH}"
