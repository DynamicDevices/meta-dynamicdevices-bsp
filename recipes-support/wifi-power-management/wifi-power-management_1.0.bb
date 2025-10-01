SUMMARY = "WiFi Power Management for E-ink Board"
DESCRIPTION = "Optimizes power consumption for the NXP IW612 WiFi module on the e-ink board"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://wifi-power-management.service \
    file://wifi-power-management.sh \
"

SRC_URI:append:imx8mm-jaguar-sentai = " \
    file://imx8mm-jaguar-sentai-wifi-pm.service \
    file://imx8mm-jaguar-sentai-wifi-pm.sh \
"

S = "${WORKDIR}"

RDEPENDS:${PN} = "bash iw wireless-tools"

inherit systemd

SYSTEMD_SERVICE:${PN} = "wifi-power-management.service"
SYSTEMD_SERVICE:${PN}:imx8mm-jaguar-sentai = "imx8mm-jaguar-sentai-wifi-pm.service"
SYSTEMD_AUTO_ENABLE = "enable"

do_install() {
    # Install systemd service
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/wifi-power-management.service ${D}${systemd_system_unitdir}/

    # Install script
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/wifi-power-management.sh ${D}${bindir}/
}

do_install:append:imx8mm-jaguar-sentai() {
    # Install imx8mm-jaguar-sentai specific service and script
    install -m 0644 ${WORKDIR}/imx8mm-jaguar-sentai-wifi-pm.service ${D}${systemd_system_unitdir}/
    install -m 0755 ${WORKDIR}/imx8mm-jaguar-sentai-wifi-pm.sh ${D}${bindir}/
}

FILES:${PN} = " \
    ${systemd_system_unitdir}/wifi-power-management.service \
    ${bindir}/wifi-power-management.sh \
"

FILES:${PN}:append:imx8mm-jaguar-sentai = " \
    ${systemd_system_unitdir}/imx8mm-jaguar-sentai-wifi-pm.service \
    ${bindir}/imx8mm-jaguar-sentai-wifi-pm.sh \
"
