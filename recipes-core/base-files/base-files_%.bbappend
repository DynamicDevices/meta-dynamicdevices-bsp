FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://dynamic-devices-banner"
SRC_URI:append:imx8mm-jaguar-sentai = " file://sentai-banner"
SRC_URI:append:imx8mm-jaguar-dt510 = " \
    file://dt510-banner \
    ${@bb.utils.contains('MACHINE_FEATURES', 'bq25792-charger', 'file://bq257xx-charger-modprobe.conf', '', d)} \
"
SRC_URI:append:imx8mm-jaguar-screen = " \
    file://99-z-jaguar-screen.conf \
    file://99-jaguar-screen-reboot-watchdog.conf \
"

do_install:append() {
    # Install shared Dynamic Devices banner
    install -d ${D}${datadir}/dynamic-devices
    install -m 644 ${WORKDIR}/dynamic-devices-banner ${D}${datadir}/dynamic-devices/banner
    
    # Create MOTD as symlink to shared banner
    ln -sf ${datadir}/dynamic-devices/banner ${D}${sysconfdir}/motd
    
    # Create SSH banner directory and symlink
    install -d ${D}${sysconfdir}/ssh
    ln -sf ${datadir}/dynamic-devices/banner ${D}${sysconfdir}/ssh/banner
}

do_install:append:imx8mm-jaguar-sentai() {
    # For Sentai machine, install Sentai-specific banner
    install -m 644 ${WORKDIR}/sentai-banner ${D}${datadir}/dynamic-devices/banner
    install -m 644 ${WORKDIR}/sentai-banner ${D}${sysconfdir}/ssh/banner
}

do_install:append:imx8mm-jaguar-dt510() {
    # For DT510 machine, install DT510-specific banner
    install -m 644 ${WORKDIR}/dt510-banner ${D}${datadir}/dynamic-devices/banner
    install -m 644 ${WORKDIR}/dt510-banner ${D}${sysconfdir}/ssh/banner

    if ${@bb.utils.contains('MACHINE_FEATURES', 'bq25792-charger', 'true', 'false', d)}; then
        install -d ${D}${sysconfdir}/modprobe.d
        install -m 0644 ${WORKDIR}/bq257xx-charger-modprobe.conf \
            ${D}${sysconfdir}/modprobe.d/bq257xx-charger.conf
    fi
}

do_install:append:imx8mm-jaguar-screen() {
    # The procps default enables martian-source logging globally. Keep real
    # diagnostics on UART, but do not flood it with rejected network packets.
    # This filename sorts after /etc/sysctl.d/99-sysctl.conf.
    install -d ${D}${sysconfdir}/sysctl.d
    install -m 0644 ${WORKDIR}/99-z-jaguar-screen.conf \
        ${D}${sysconfdir}/sysctl.d/99-z-jaguar-screen.conf

    # The native display shutdown path can stall after systemd has completed
    # its final sync. Bound that already-safe window instead of changing the
    # proven bootloader or DRM handoff configuration.
    install -d ${D}${sysconfdir}/systemd/system.conf.d
    install -m 0644 ${WORKDIR}/99-jaguar-screen-reboot-watchdog.conf \
        ${D}${sysconfdir}/systemd/system.conf.d/99-jaguar-screen-reboot-watchdog.conf
}

FILES:${PN} += " \
    ${datadir}/dynamic-devices/banner \
    ${sysconfdir}/motd \
    ${sysconfdir}/ssh/banner \
"

FILES:${PN}:append:imx8mm-jaguar-dt510 = "${@bb.utils.contains('MACHINE_FEATURES', 'bq25792-charger', ' ${sysconfdir}/modprobe.d/bq257xx-charger.conf', '', d)}"
FILES:${PN}:append:imx8mm-jaguar-screen = " \
    ${sysconfdir}/sysctl.d/99-z-jaguar-screen.conf \
    ${sysconfdir}/systemd/system.conf.d/99-jaguar-screen-reboot-watchdog.conf \
"
