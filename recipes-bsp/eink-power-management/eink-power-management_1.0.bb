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

# WiFi connect service for imx93-jaguar-eink only
SRC_URI:append:imx93-jaguar-eink = " file://wifi-connect.service file://cpu-power-optimize.sh file://cpu-power-optimize.service"

S = "${WORKDIR}"

RDEPENDS:${PN} = "bash iw wireless-tools eink-power-cli"

inherit systemd

SYSTEMD_SERVICE:${PN} = "setup-wowlan.service eink-restart.service eink-shutdown.service wifi-suspend.service wifi-resume.service"
# WiFi connect service for imx93-jaguar-eink only (ensures prompt WiFi connection on boot)
SYSTEMD_SERVICE:${PN}:imx93-jaguar-eink = "setup-wowlan.service eink-restart.service eink-shutdown.service wifi-suspend.service wifi-resume.service wifi-connect.service cpu-power-optimize.service"
# Active services:
# - setup-wowlan.service: WiFi wake-on-LAN functionality (magic packets only)
# - eink-restart.service: Custom power-optimized restart handling via eink-power-cli
# - eink-shutdown.service: Custom power-optimized shutdown handling via eink-power-cli
# - wifi-suspend.service: WiFi interface shutdown before system suspend
# - wifi-resume.service: WiFi interface restoration after system resume
# - wifi-connect.service: Ensure WiFi connection on boot (imx93-jaguar-eink only, bypasses NetworkManager retry delay)
# PHASE 5.3: Re-enabling E-Ink power management services - WoL, restart/shutdown handlers, WiFi suspend/resume
SYSTEMD_AUTO_ENABLE = "enable"

do_install() {
    # Install systemd services
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/setup-wowlan.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/eink-restart.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/eink-shutdown.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/wifi-suspend.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/wifi-resume.service ${D}${systemd_system_unitdir}/
    # WiFi connect service and CPU power optimization for imx93-jaguar-eink only
    if [ "${MACHINE}" = "imx93-jaguar-eink" ]; then
        install -m 0644 ${WORKDIR}/wifi-connect.service ${D}${systemd_system_unitdir}/
        install -m 0644 ${WORKDIR}/cpu-power-optimize.service ${D}${systemd_system_unitdir}/
    fi

    # Install scripts
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/setup-wowlan.sh ${D}${bindir}/
    install -m 0755 ${WORKDIR}/eink-restart.sh ${D}${bindir}/
    install -m 0755 ${WORKDIR}/eink-shutdown.sh ${D}${bindir}/
    install -m 0755 ${WORKDIR}/wifi-suspend.sh ${D}${bindir}/
    install -m 0755 ${WORKDIR}/wifi-resume.sh ${D}${bindir}/
    # CPU power optimization script for imx93-jaguar-eink only
    if [ "${MACHINE}" = "imx93-jaguar-eink" ]; then
        install -m 0755 ${WORKDIR}/cpu-power-optimize.sh ${D}${bindir}/
    fi

    # Install systemd system-sleep hook
    install -d ${D}${libdir}/systemd/system-sleep
    install -m 0755 ${WORKDIR}/wifi-power-management ${D}${libdir}/systemd/system-sleep/

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
    ${libdir}/systemd/system-sleep \
    ${libdir}/systemd/system-sleep/wifi-power-management \
    ${sysconfdir}/NetworkManager \
    ${sysconfdir}/NetworkManager/conf.d \
    ${sysconfdir}/NetworkManager/conf.d/99-disable-mac-randomization.conf \
"

# WiFi connect service and CPU power optimization for imx93-jaguar-eink only
FILES:${PN}:imx93-jaguar-eink += "${systemd_system_unitdir}/wifi-connect.service ${systemd_system_unitdir}/cpu-power-optimize.service ${bindir}/cpu-power-optimize.sh"
