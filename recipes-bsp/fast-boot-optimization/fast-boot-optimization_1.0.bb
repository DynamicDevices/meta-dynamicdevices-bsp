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
    file://wifi-priority.service \
    file://wifi-priority-init.sh \
    file://delayed-components.service \
    file://delayed-components.sh \
"

S = "${WORKDIR}"

RDEPENDS:${PN} = "systemd kmod"

do_install() {
    # Install systemd services for workflow optimization
    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${WORKDIR}/delayed-wireless.service ${D}${systemd_unitdir}/system/
    install -m 0644 ${WORKDIR}/delayed-wireless-aggressive.service ${D}${systemd_unitdir}/system/
    install -m 0644 ${WORKDIR}/wifi-priority.service ${D}${systemd_unitdir}/system/
    install -m 0644 ${WORKDIR}/delayed-components.service ${D}${systemd_unitdir}/system/

    # Install scripts for workflow optimization
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/delayed-wireless.sh ${D}${bindir}/
    install -m 0755 ${WORKDIR}/delayed-wireless-aggressive.sh ${D}${bindir}/
    install -m 0755 ${WORKDIR}/wifi-priority-init.sh ${D}${bindir}/
    install -m 0755 ${WORKDIR}/delayed-components.sh ${D}${bindir}/
    
    # Install systemd configuration optimizations
    install -d ${D}${sysconfdir}/systemd/system.conf.d
    install -m 0644 ${WORKDIR}/fast-boot.conf ${D}${sysconfdir}/systemd/system.conf.d/
    install -m 0644 ${WORKDIR}/systemd-aggressive.conf ${D}${sysconfdir}/systemd/system.conf.d/
}

SYSTEMD_SERVICE:${PN} = "wifi-priority.service delayed-components.service"

inherit systemd

FILES:${PN} += " \
    ${systemd_unitdir}/system/delayed-wireless.service \
    ${systemd_unitdir}/system/delayed-wireless-aggressive.service \
    ${systemd_unitdir}/system/wifi-priority.service \
    ${systemd_unitdir}/system/delayed-components.service \
    ${bindir}/delayed-wireless.sh \
    ${bindir}/delayed-wireless-aggressive.sh \
    ${bindir}/wifi-priority-init.sh \
    ${bindir}/delayed-components.sh \
    ${sysconfdir}/systemd/system.conf.d/fast-boot.conf \
    ${sysconfdir}/systemd/system.conf.d/systemd-aggressive.conf \
"
