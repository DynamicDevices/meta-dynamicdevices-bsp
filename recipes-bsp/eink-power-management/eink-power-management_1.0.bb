SUMMARY = "E-ink Board Power Management"
DESCRIPTION = "Active power management scripts for the e-ink board: Wake-on-LAN configuration \
and custom restart handler using eink-power-cli for MCXC143VFM power controller integration."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://setup-wowlan.sh \
    file://setup-wowlan.service \
    file://eink-restart.sh \
    file://eink-restart.service \
"

S = "${WORKDIR}"

RDEPENDS:${PN} = "bash iw wireless-tools eink-power-cli"

inherit systemd

SYSTEMD_SERVICE:${PN} = "setup-wowlan.service eink-restart.service"
# Active services:
# - setup-wowlan.service: WiFi wake-on-LAN functionality (magic packets only)
# - eink-restart.service: Custom power-optimized restart handling via eink-power-cli
SYSTEMD_AUTO_ENABLE = "enable"

do_install() {
    # Install systemd services
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/setup-wowlan.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/eink-restart.service ${D}${systemd_system_unitdir}/

    # Install scripts
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/setup-wowlan.sh ${D}${bindir}/
    install -m 0755 ${WORKDIR}/eink-restart.sh ${D}${bindir}/
}

FILES:${PN} = " \
    ${systemd_system_unitdir}/setup-wowlan.service \
    ${systemd_system_unitdir}/eink-restart.service \
    ${bindir}/setup-wowlan.sh \
    ${bindir}/eink-restart.sh \
"
