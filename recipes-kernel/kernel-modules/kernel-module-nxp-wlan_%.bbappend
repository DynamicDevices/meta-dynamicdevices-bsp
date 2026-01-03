FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# Only apply NXP WLAN patch for Dynamic Devices machines that use NXP WiFi
SRC_URI:append:imx8mm-jaguar-sentai = " file://0001-nxp-wlan-disable-scan-progress-warning.patch"
SRC_URI:append:imx8mm-jaguar-inst = " file://0001-nxp-wlan-disable-scan-progress-warning.patch"
SRC_URI:append:imx8mm-jaguar-handheld = " file://0001-nxp-wlan-disable-scan-progress-warning.patch"
SRC_URI:append:imx8mm-jaguar-phasora = " file://0001-nxp-wlan-disable-scan-progress-warning.patch"
SRC_URI:append:imx8mm-jaguar-dt510 = " file://0001-nxp-wlan-disable-scan-progress-warning.patch"
SRC_URI:append:imx93-jaguar-eink = " file://0001-nxp-wlan-disable-scan-progress-warning.patch"

# Configure WiFi module parameters for imx93-jaguar-eink
# Set interface name to wlan0 and disable debug logging

inherit systemd

SYSTEMD_SERVICE:${PN}:imx8mm-jaguar-sentai = "enable-wifi.service"
SYSTEMD_AUTO_ENABLE:${PN}:imx8mm-jaguar-sentai = "enable"
SYSTEMD_SERVICE:${PN}:imx8mm-jaguar-dt510 = "enable-wifi.service"
SYSTEMD_AUTO_ENABLE:${PN}:imx8mm-jaguar-dt510 = "enable"

SRC_URI:append:imx8mm-jaguar-sentai = "\
    file://enable-wifi.sh \
    file://enable-wifi.service \
    file://99-ignore-uap.conf \
"

do_install:append:imx8mm-jaguar-sentai() {
    install -d ${D}/${bindir}
    install -D -m 0755 ${WORKDIR}/*.sh ${D}${bindir}
    install -d ${D}/${systemd_unitdir}/system
    install -m 0644 ${WORKDIR}/*.service ${D}/${systemd_unitdir}/system
    install -d ${D}${sysconfdir}/NetworkManager/conf.d
    install -D -m 0644 ${WORKDIR}/99-ignore-uap.conf ${D}${sysconfdir}/NetworkManager/conf.d/99-ignore-uap.conf
}

FILES:${PN}:imx8mm-jaguar-sentai += "${systemd_unitdir}/system/*.service ${bindir}/*.sh ${sysconfdir}/NetworkManager/conf.d/99-ignore-uap.conf"

SRC_URI:append:imx8mm-jaguar-dt510 = "\
    file://enable-wifi.sh \
    file://enable-wifi.service \
    file://99-ignore-uap.conf \
"

do_install:append:imx8mm-jaguar-dt510() {
    install -d ${D}/${bindir}
    install -D -m 0755 ${WORKDIR}/*.sh ${D}${bindir}
    install -d ${D}/${systemd_unitdir}/system
    install -m 0644 ${WORKDIR}/*.service ${D}/${systemd_unitdir}/system
    install -d ${D}${sysconfdir}/NetworkManager/conf.d
    install -D -m 0644 ${WORKDIR}/99-ignore-uap.conf ${D}${sysconfdir}/NetworkManager/conf.d/99-ignore-uap.conf
}

FILES:${PN}:imx8mm-jaguar-dt510 += "${systemd_unitdir}/system/*.service ${bindir}/*.sh ${sysconfdir}/NetworkManager/conf.d/99-ignore-uap.conf"

# Add WiFi interface management configurations and udev rules for imx93-jaguar-eink
SRC_URI:append:imx93-jaguar-eink = " file://99-ignore-secondary-wifi.conf file://70-wifi-interface-rename.rules file://71-wifi-mlan0-down.rules"

# WiFi module parameters (debug only) are configured in the machine configuration

do_install:append:imx93-jaguar-eink() {
    # Install NetworkManager configuration to ignore secondary WiFi interfaces
    install -d ${D}${sysconfdir}/NetworkManager/conf.d
    install -D -m 0644 ${WORKDIR}/99-ignore-secondary-wifi.conf ${D}${sysconfdir}/NetworkManager/conf.d/99-ignore-secondary-wifi.conf
    
    # Install udev rules for interface management
    install -d ${D}${sysconfdir}/udev/rules.d
    install -D -m 0644 ${WORKDIR}/70-wifi-interface-rename.rules ${D}${sysconfdir}/udev/rules.d/70-wifi-interface-rename.rules
    install -D -m 0644 ${WORKDIR}/71-wifi-mlan0-down.rules ${D}${sysconfdir}/udev/rules.d/71-wifi-mlan0-down.rules
}

FILES:${PN}:imx93-jaguar-eink += "${sysconfdir}/NetworkManager/conf.d/99-ignore-secondary-wifi.conf ${sysconfdir}/udev/rules.d/70-wifi-interface-rename.rules ${sysconfdir}/udev/rules.d/71-wifi-mlan0-down.rules"

# Debug messages are now disabled via drvdbg=0 module parameter
