FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# Only apply NXP WLAN patch for Dynamic Devices machines that use NXP WiFi
SRC_URI:append:imx8mm-jaguar-sentai = " file://01-disable-scan-in-progress-warning.patch"
SRC_URI:append:imx8mm-jaguar-inst = " file://01-disable-scan-in-progress-warning.patch"
SRC_URI:append:imx8mm-jaguar-handheld = " file://01-disable-scan-in-progress-warning.patch"
SRC_URI:append:imx8mm-jaguar-phasora = " file://01-disable-scan-in-progress-warning.patch"
SRC_URI:append:imx93-jaguar-eink = " file://01-disable-scan-in-progress-warning.patch"

# Configure WiFi module parameters for imx93-jaguar-eink
# Set interface name to wlan0 and disable debug logging

inherit systemd

SYSTEMD_SERVICE:${PN}:imx8mm-jaguar-sentai = "enable-wifi.service"
SYSTEMD_AUTO_ENABLE:${PN}:imx8mm-jaguar-sentai = "enable"

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

# Add UAP ignore configuration and udev rule for imx93-jaguar-eink
SRC_URI:append:imx93-jaguar-eink = " file://99-ignore-uap.conf file://70-wifi-interface-rename.rules"

# WiFi module parameters (debug only) are configured in the machine configuration

do_install:append:imx93-jaguar-eink() {
    install -d ${D}${sysconfdir}/NetworkManager/conf.d
    install -D -m 0644 ${WORKDIR}/99-ignore-uap.conf ${D}${sysconfdir}/NetworkManager/conf.d/99-ignore-uap.conf
    
    # Install udev rule for interface renaming
    install -d ${D}${sysconfdir}/udev/rules.d
    install -D -m 0644 ${WORKDIR}/70-wifi-interface-rename.rules ${D}${sysconfdir}/udev/rules.d/70-wifi-interface-rename.rules
}

FILES:${PN}:imx93-jaguar-eink += "${sysconfdir}/NetworkManager/conf.d/99-ignore-uap.conf ${sysconfdir}/udev/rules.d/70-wifi-interface-rename.rules"

# Debug messages are now disabled via drvdbg=0 module parameter
