FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://dynamic-devices-banner"

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
    # For Sentai machine, use SSH banner (installed by openssh recipe) for MOTD
    rm -f ${D}${sysconfdir}/motd
    ln -sf ${sysconfdir}/ssh/banner ${D}${sysconfdir}/motd
}

FILES:${PN} += " \
    ${datadir}/dynamic-devices/banner \
    ${sysconfdir}/motd \
    ${sysconfdir}/ssh/banner \
"
