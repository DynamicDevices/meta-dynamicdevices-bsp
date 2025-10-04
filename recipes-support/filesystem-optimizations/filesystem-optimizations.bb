DESCRIPTION = "Filesystem Optimizations for E-Ink Board Power Efficiency"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://filesystem-optimizations.service \
    file://filesystem-optimizations.sh \
"

S = "${WORKDIR}"

SYSTEMD_AUTO_ENABLE = "enable"
SYSTEMD_SERVICE:${PN} = "filesystem-optimizations.service"

inherit systemd

RDEPENDS:${PN} = "bash util-linux"
COMPATIBLE_MACHINE = "imx93-jaguar-eink"

do_install() {
    # Install systemd service
    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${WORKDIR}/filesystem-optimizations.service ${D}${systemd_unitdir}/system/

    # Install optimization script
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/filesystem-optimizations.sh ${D}${bindir}/
}

FILES:${PN} += " \
    ${systemd_unitdir}/system/filesystem-optimizations.service \
    ${bindir}/filesystem-optimizations.sh \
"
