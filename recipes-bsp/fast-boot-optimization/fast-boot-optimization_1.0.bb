SUMMARY = "Fast boot optimizations for imx93-jaguar-eink"
DESCRIPTION = "Systemd service optimizations and delayed module loading for faster boot"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://delayed-wireless.service \
    file://delayed-wireless.sh \
    file://fast-boot.conf \
    file://delayed-wireless-aggressive.service \
    file://delayed-wireless-aggressive.sh \
    file://systemd-aggressive.conf \
"

S = "${WORKDIR}"

RDEPENDS:${PN} = "systemd kmod"

do_install() {
    # Install systemd services for delayed wireless loading
    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${WORKDIR}/delayed-wireless.service ${D}${systemd_unitdir}/system/
    install -m 0644 ${WORKDIR}/delayed-wireless-aggressive.service ${D}${systemd_unitdir}/system/

    # Install scripts for delayed wireless loading
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/delayed-wireless.sh ${D}${bindir}/
    install -m 0755 ${WORKDIR}/delayed-wireless-aggressive.sh ${D}${bindir}/
    
    # Install systemd configuration optimizations
    install -d ${D}${sysconfdir}/systemd/system.conf.d
    install -m 0644 ${WORKDIR}/fast-boot.conf ${D}${sysconfdir}/systemd/system.conf.d/
    install -m 0644 ${WORKDIR}/systemd-aggressive.conf ${D}${sysconfdir}/systemd/system.conf.d/
}

SYSTEMD_SERVICE:${PN} = "delayed-wireless-aggressive.service"

inherit systemd

FILES:${PN} += " \
    ${systemd_unitdir}/system/delayed-wireless.service \
    ${systemd_unitdir}/system/delayed-wireless-aggressive.service \
    ${bindir}/delayed-wireless.sh \
    ${bindir}/delayed-wireless-aggressive.sh \
    ${sysconfdir}/systemd/system.conf.d/fast-boot.conf \
    ${sysconfdir}/systemd/system.conf.d/systemd-aggressive.conf \
"
