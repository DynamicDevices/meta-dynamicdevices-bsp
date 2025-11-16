SUMMARY = "E-ink Board Power Management"
DESCRIPTION = "Active power management scripts for the e-ink board: Wake-on-LAN configuration, \
custom restart/shutdown handlers, and WiFi suspend/resume management using eink-power-cli for MCXC143VFM power controller integration."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://setup-wowlan.sh \
    file://setup-wowlan.service \
    file://eink-restart.sh \
    file://eink-restart.service \
    file://eink-shutdown.sh \
    file://eink-shutdown.service \
    file://wifi-suspend.sh \
    file://wifi-suspend.service \
    file://wifi-resume.sh \
    file://wifi-resume.service \
    file://wifi-power-management \
    file://99-disable-mac-randomization.conf \
"

S = "${WORKDIR}"

RDEPENDS:${PN} = "bash iw wireless-tools eink-power-cli"

inherit systemd

SYSTEMD_SERVICE:${PN} = "setup-wowlan.service eink-restart.service eink-shutdown.service wifi-suspend.service wifi-resume.service"
# Active services:
# - setup-wowlan.service: WiFi wake-on-LAN functionality (magic packets only)
# - eink-restart.service: Custom power-optimized restart handling via eink-power-cli
# - eink-shutdown.service: Custom power-optimized shutdown handling via eink-power-cli
# - wifi-suspend.service: WiFi interface shutdown before system suspend
# - wifi-resume.service: WiFi interface restoration after system resume
# TEMPORARILY DISABLED FOR BOOT DEBUGGING - These services may be causing boot failures
SYSTEMD_AUTO_ENABLE = "disable"

do_install() {
    # Install systemd services
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/setup-wowlan.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/eink-restart.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/eink-shutdown.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/wifi-suspend.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/wifi-resume.service ${D}${systemd_system_unitdir}/

    # Install scripts
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/setup-wowlan.sh ${D}${bindir}/
    install -m 0755 ${WORKDIR}/eink-restart.sh ${D}${bindir}/
    install -m 0755 ${WORKDIR}/eink-shutdown.sh ${D}${bindir}/
    install -m 0755 ${WORKDIR}/wifi-suspend.sh ${D}${bindir}/
    install -m 0755 ${WORKDIR}/wifi-resume.sh ${D}${bindir}/

    # Install systemd system-sleep hook
    install -d ${D}${prefix}/lib/systemd/system-sleep
    install -m 0755 ${WORKDIR}/wifi-power-management ${D}${prefix}/lib/systemd/system-sleep/

    # Install NetworkManager configuration to disable MAC randomization
    install -d ${D}${sysconfdir}/NetworkManager/conf.d
    install -m 0644 ${WORKDIR}/99-disable-mac-randomization.conf ${D}${sysconfdir}/NetworkManager/conf.d/
}

FILES:${PN} = " \
    ${systemd_system_unitdir}/setup-wowlan.service \
    ${systemd_system_unitdir}/eink-restart.service \
    ${systemd_system_unitdir}/eink-shutdown.service \
    ${systemd_system_unitdir}/wifi-suspend.service \
    ${systemd_system_unitdir}/wifi-resume.service \
    ${bindir}/setup-wowlan.sh \
    ${bindir}/eink-restart.sh \
    ${bindir}/eink-shutdown.sh \
    ${bindir}/wifi-suspend.sh \
    ${bindir}/wifi-resume.sh \
    ${prefix}/lib/systemd/system-sleep/wifi-power-management \
    ${sysconfdir}/NetworkManager/conf.d/99-disable-mac-randomization.conf \
"
