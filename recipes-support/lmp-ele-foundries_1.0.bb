SUMMARY = "EdgeLock Enclave (ELE) integration with Foundries.io LMP"
DESCRIPTION = "Provides ELE-based device provisioning and registration for Foundries.io Linux microPlatform"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=0835ade698e0bcf8506ecda2f7b4f302"

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI = "file://lmp-ele-auto-register \
           file://lmp-ele-auto-register.service \
           file://ele-foundries-cli.py \
           file://default.env \
           file://hsm-config-template \
           file://ele-provisioning-setup.sh \
           file://ele-pkcs11.c \
           file://test-ele-foundries-integration.sh \
           file://README.md \
           file://LICENSE"

DEPENDS = "openssl gcc-native"
RDEPENDS:${PN} = "python3-core python3-requests openssl-bin aktualizr-lite"

S = "${WORKDIR}"

inherit systemd

SYSTEMD_SERVICE:${PN} = "lmp-ele-auto-register.service"

do_compile() {
    # Compile ELE PKCS#11 module
    ${CC} ${CFLAGS} ${LDFLAGS} -shared -fPIC \
        ${WORKDIR}/ele-pkcs11.c \
        -o ${S}/ele-pkcs11.so || bbwarn "Failed to compile ELE PKCS#11 module"
}

do_install() {
    # Install main registration script
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/lmp-ele-auto-register ${D}${bindir}/
    install -m 0755 ${WORKDIR}/ele-foundries-cli.py ${D}${bindir}/
    install -m 0755 ${WORKDIR}/ele-provisioning-setup.sh ${D}${bindir}/
    install -m 0755 ${WORKDIR}/test-ele-foundries-integration.sh ${D}${bindir}/
    
    # Install PKCS#11 module
    install -d ${D}${libdir}/pkcs11
    if [ -f ${S}/ele-pkcs11.so ]; then
        install -m 0755 ${S}/ele-pkcs11.so ${D}${libdir}/pkcs11/
    else
        bbwarn "ELE PKCS#11 module not compiled, creating placeholder"
        touch ${D}${libdir}/pkcs11/ele-pkcs11.so
    fi
    
    # Install systemd service
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/lmp-ele-auto-register.service ${D}${systemd_system_unitdir}/
    
    # Install configuration
    install -d ${D}${sysconfdir}/default
    install -m 0644 ${WORKDIR}/default.env ${D}${sysconfdir}/default/lmp-ele-auto-register
    
    # Install HSM configuration template and documentation
    install -d ${D}${datadir}/lmp-ele-foundries
    install -m 0644 ${WORKDIR}/hsm-config-template ${D}${datadir}/lmp-ele-foundries/
    install -m 0644 ${WORKDIR}/README.md ${D}${datadir}/lmp-ele-foundries/
    
    # Create sota directory
    install -d ${D}${localstatedir}/sota
}

FILES:${PN} = "${bindir}/lmp-ele-auto-register \
               ${bindir}/ele-foundries-cli.py \
               ${bindir}/ele-provisioning-setup.sh \
               ${bindir}/test-ele-foundries-integration.sh \
               ${libdir}/pkcs11/ele-pkcs11.so \
               ${systemd_system_unitdir}/lmp-ele-auto-register.service \
               ${sysconfdir}/default/lmp-ele-auto-register \
               ${datadir}/lmp-ele-foundries/hsm-config-template \
               ${datadir}/lmp-ele-foundries/README.md \
               ${localstatedir}/sota"

# Only install on i.MX93 platforms with ELE support
COMPATIBLE_MACHINE = "imx93-jaguar-eink"
