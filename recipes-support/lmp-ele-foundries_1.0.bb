SUMMARY = "EdgeLock Enclave (ELE) integration with Foundries.io LMP"
DESCRIPTION = "Provides ELE-based device provisioning and registration for Foundries.io Linux microPlatform"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=0835ade698e0bcf8506ecda2f7b4f302"

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI = "file://lmp-ele-auto-register \
           file://lmp-ele-auto-register.service \
           file://ele-foundries-cli.py \
           file://default.env \
           file://LICENSE"

DEPENDS = "openssl"
RDEPENDS:${PN} = "python3-core python3-requests openssl-bin aktualizr-lite"

S = "${WORKDIR}"

inherit systemd

SYSTEMD_SERVICE:${PN} = "lmp-ele-auto-register.service"

do_install() {
    # Install main registration script
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/lmp-ele-auto-register ${D}${bindir}/
    install -m 0755 ${WORKDIR}/ele-foundries-cli.py ${D}${bindir}/
    
    # Install systemd service
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/lmp-ele-auto-register.service ${D}${systemd_system_unitdir}/
    
    # Install configuration
    install -d ${D}${sysconfdir}/default
    install -m 0644 ${WORKDIR}/default.env ${D}${sysconfdir}/default/lmp-ele-auto-register
    
    # Create sota directory
    install -d ${D}${localstatedir}/sota
}

FILES:${PN} = "${bindir}/lmp-ele-auto-register \
               ${bindir}/ele-foundries-cli.py \
               ${systemd_system_unitdir}/lmp-ele-auto-register.service \
               ${sysconfdir}/default/lmp-ele-auto-register \
               ${localstatedir}/sota"

# Only install on i.MX93 platforms with ELE support
COMPATIBLE_MACHINE = "(mx9-generic-bsp)"
