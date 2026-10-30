SUMMARY = "Jaguar Screen speaker-specific TAS2555 DSP configuration"
DESCRIPTION = "Installs the board and speaker configuration required for protected TAS2555 playback. No generic tuning or unprotected ROM fallback is supplied."

# Supplied privately by the hardware owner. Confirm the actual licence and
# redistribution rights before distributing the binary or images containing it.
LICENSE = "CLOSED"

inherit features_check

COMPATIBLE_MACHINE = "^imx8mm-jaguar-screen$"
REQUIRED_MACHINE_FEATURES = "tas2555"
CONFLICT_MACHINE_FEATURES = "tas2555-rom1-dev"
PACKAGE_ARCH = "${MACHINE_ARCH}"

# Provide the approved binary in files/, or through a private layer's
# FILESEXTRAPATHS. Its absence intentionally fails fetch rather than silently
# shipping an image with a non-functional amplifier.
SRC_URI = "${@bb.utils.contains('MACHINE_FEATURES', 'tas2555-rom1-dev', '', 'file://tas2555_uCDSP.bin', d)}"
S = "${WORKDIR}"

do_install() {
    if [ ! -s "${WORKDIR}/tas2555_uCDSP.bin" ]; then
        bbfatal "Supply the approved Jaguar Screen speaker-specific tas2555_uCDSP.bin"
    fi
    install -d ${D}${nonarch_base_libdir}/firmware
    install -m 0644 ${WORKDIR}/tas2555_uCDSP.bin \
        ${D}${nonarch_base_libdir}/firmware/tas2555_uCDSP.bin
}

FILES:${PN} = "${nonarch_base_libdir}/firmware/tas2555_uCDSP.bin"
