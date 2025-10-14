SUMMARY = "Acconeer XM125 Radar Module Control and Firmware Management"
DESCRIPTION = "Comprehensive control utilities and firmware files for the Acconeer XM125 radar module including GPIO control, reset sequences, and firmware flashing"
HOMEPAGE = "https://developer.acconeer.com/"
LICENSE = "CLOSED"
LIC_FILES_CHKSUM = ""

SECTION = "base"
DEPENDS = "libgpiod stm32flash"
RDEPENDS:${PN} = "libgpiod-tools i2c-tools bash stm32flash"

# Version should match the XM125 firmware version
PV = "1.0.0"
PR = "r2"

SRC_URI = " \
    file://xm125-control.sh \
    file://xm125-firmware-flash.sh \
    file://xm125-firmware-manager.service \
    file://test-gpio-commands.sh \
    file://README-firmware.md \
    file://i2c_presence_detector.bin \
    file://i2c_distance_detector.bin \
    file://i2c_ref_app_breathing.bin \
"

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
    # Install XM125 control and management scripts
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/xm125-control.sh ${D}${bindir}/
    install -m 0755 ${WORKDIR}/xm125-firmware-flash.sh ${D}${bindir}/
    install -m 0755 ${WORKDIR}/test-gpio-commands.sh ${D}${bindir}/
    
    # Install systemd service
    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${WORKDIR}/xm125-firmware-manager.service ${D}${systemd_unitdir}/system/
    
    # Install firmware files in /lib/firmware/acconeer/
    install -d ${D}${nonarch_base_libdir}/firmware/acconeer
    install -m 0644 ${WORKDIR}/i2c_presence_detector.bin ${D}${nonarch_base_libdir}/firmware/acconeer/
    install -m 0644 ${WORKDIR}/i2c_distance_detector.bin ${D}${nonarch_base_libdir}/firmware/acconeer/
    install -m 0644 ${WORKDIR}/i2c_ref_app_breathing.bin ${D}${nonarch_base_libdir}/firmware/acconeer/
    
    # Create firmware directory for additional files (legacy location)
    install -d ${D}${datadir}/xm125-firmware
    
    # Install documentation
    install -m 0644 ${WORKDIR}/README-firmware.md ${D}${datadir}/xm125-firmware/
}

FILES:${PN} = " \
    ${bindir}/xm125-control.sh \
    ${bindir}/xm125-firmware-* \
    ${bindir}/test-gpio-commands.sh \
    ${systemd_unitdir}/system/xm125-firmware-manager.service \
    ${nonarch_base_libdir}/firmware/acconeer/* \
    ${datadir}/xm125-firmware/* \
"

inherit systemd

SYSTEMD_SERVICE:${PN} = "xm125-firmware-manager.service"
SYSTEMD_AUTO_ENABLE:${PN} = "disable"

# Package information
PACKAGE_ARCH = "${MACHINE_ARCH}"
