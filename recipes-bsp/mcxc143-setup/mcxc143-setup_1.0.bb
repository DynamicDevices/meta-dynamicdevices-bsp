SUMMARY = "MCXC143VFM Power Microcontroller Setup Service"
DESCRIPTION = "First-boot service to configure serial connection to MCXC143VFM \
power management microcontroller on /dev/ttyLP2 for imx93-jaguar-eink board."

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

# Only install on imx93-jaguar-eink machine
COMPATIBLE_MACHINE = "imx93-jaguar-eink"

SRC_URI = " \
    file://mcxc143-setup.sh \
    file://mcxc143-setup.service \
    file://mcxc143-first-boot.service \
    file://lpuart7-keep-active.service \
"

S = "${WORKDIR}"

RDEPENDS:${PN} = "bash coreutils"

inherit systemd

SYSTEMD_SERVICE:${PN} = "mcxc143-first-boot.service lpuart7-keep-active.service"
# PHASE 5.2: Re-enabling MCXC143VFM power microcontroller setup services
SYSTEMD_AUTO_ENABLE = "enable"

do_install() {
    # Install setup script
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/mcxc143-setup.sh ${D}${bindir}/mcxc143-setup.sh
    
    # Install systemd services
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/mcxc143-setup.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/mcxc143-first-boot.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/lpuart7-keep-active.service ${D}${systemd_system_unitdir}/
    
    # Create state directory for tracking first boot
    install -d ${D}${localstatedir}/lib/mcxc143
}

FILES:${PN} = " \
    ${bindir}/mcxc143-setup.sh \
    ${systemd_system_unitdir}/mcxc143-setup.service \
    ${systemd_system_unitdir}/mcxc143-first-boot.service \
    ${localstatedir}/lib/mcxc143 \
"
