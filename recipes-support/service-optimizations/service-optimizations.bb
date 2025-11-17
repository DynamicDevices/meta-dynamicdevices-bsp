DESCRIPTION = "Service Optimizations for E-Ink Board Power Efficiency"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://service-optimizations.service \
    file://service-optimizations.sh \
"

S = "${WORKDIR}"

# PHASE 5.1: Re-enabling service optimizations - power optimization service disabling
SYSTEMD_AUTO_ENABLE = "enable"
SYSTEMD_SERVICE:${PN} = "service-optimizations.service"

inherit systemd

RDEPENDS:${PN} = "bash systemd"
COMPATIBLE_MACHINE = "imx93-jaguar-eink"

do_install() {
    # Install systemd service
    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${WORKDIR}/service-optimizations.service ${D}${systemd_unitdir}/system/

    # Install optimization script
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/service-optimizations.sh ${D}${bindir}/
}

FILES:${PN} += " \
    ${systemd_unitdir}/system/service-optimizations.service \
    ${bindir}/service-optimizations.sh \
"
