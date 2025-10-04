DESCRIPTION = "WiFi Power Management for E-Ink Board Battery Optimization"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://wifi-power-management.service \
    file://wifi-power-management.sh \
"

S = "${WORKDIR}"

SYSTEMD_AUTO_ENABLE = "enable"
SYSTEMD_SERVICE:${PN} = "wifi-power-management.service"

inherit systemd

RDEPENDS:${PN} = "bash iw wireless-tools"
COMPATIBLE_MACHINE = "imx93-jaguar-eink"

do_install() {
    # Install systemd service
    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${WORKDIR}/wifi-power-management.service ${D}${systemd_unitdir}/system/

    # Install power management script
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/wifi-power-management.sh ${D}${bindir}/
}

FILES:${PN} += " \
    ${systemd_unitdir}/system/wifi-power-management.service \
    ${bindir}/wifi-power-management.sh \
"
