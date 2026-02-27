SUMMARY = "USB Gadget Scripts for imx8mm-jaguar-sentai"
DESCRIPTION = "USB gadget configuration scripts for CDC serial and audio gadget support. Provides setup scripts for USB composite gadget with CDC ACM serial port and UAC1/UAC2 audio."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI = " \
    file://setup-usb-serial-gadget.sh \
    file://setup-usb-mixed-audio-gadget \
    file://setup-fixed-uac2.sh \
    file://start-fixed-usb-audio.sh \
    file://usb-composite-gadget-fixed.service \
    file://usb-audio-test.sh \
    file://uac2-module-test.sh \
"

# DT510-specific: dual USB audio gadget (2x UAC1 for testing)
SRC_URI:append:imx8mm-jaguar-dt510 = " \
    file://setup-usb-dual-audio-gadget \
    file://usb-dual-audio-gadget-dt510.service \
"

S = "${WORKDIR}"

RDEPENDS:${PN} = "bash"

inherit systemd

SYSTEMD_SERVICE:${PN} = "usb-composite-gadget-fixed.service"
# DT510 uses dual audio gadget only (2x UAC2 + CDC)
SYSTEMD_SERVICE:${PN}:imx8mm-jaguar-dt510 = "usb-dual-audio-gadget-dt510.service"
SYSTEMD_AUTO_ENABLE:${PN} = "disable"
# Enable dual USB audio gadget at boot for DT510 (2x UAC2 + CDC)
SYSTEMD_AUTO_ENABLE:${PN}:imx8mm-jaguar-dt510 = "enable"

do_install() {
    # Install USB gadget setup scripts
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/setup-usb-serial-gadget.sh ${D}${bindir}/setup-usb-serial-gadget
    install -m 0755 ${WORKDIR}/setup-usb-mixed-audio-gadget ${D}${bindir}/setup-usb-mixed-audio-gadget
    install -m 0755 ${WORKDIR}/setup-fixed-uac2.sh ${D}${bindir}/setup-fixed-uac2.sh
    install -m 0755 ${WORKDIR}/start-fixed-usb-audio.sh ${D}${bindir}/start-fixed-usb-audio.sh
    install -m 0755 ${WORKDIR}/usb-audio-test.sh ${D}${bindir}/usb-audio-test.sh
    install -m 0755 ${WORKDIR}/uac2-module-test.sh ${D}${bindir}/uac2-module-test.sh
    
    # Create symlinks for convenience (matching documentation)
    ln -sf setup-usb-mixed-audio-gadget ${D}${bindir}/setup-usb-composite-gadget
    ln -sf setup-usb-mixed-audio-gadget ${D}${bindir}/setup-usb-cdc-gadget
    ln -sf setup-usb-mixed-audio-gadget ${D}${bindir}/setup-usb-audio-gadget
    
    # Install systemd service
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/usb-composite-gadget-fixed.service ${D}${systemd_system_unitdir}/
}

do_install:append:imx8mm-jaguar-dt510() {
    # DT510-specific: dual USB audio gadget (2x UAC1)
    install -m 0755 ${WORKDIR}/setup-usb-dual-audio-gadget ${D}${bindir}/setup-usb-dual-audio-gadget
    install -m 0644 ${WORKDIR}/usb-dual-audio-gadget-dt510.service ${D}${systemd_system_unitdir}/
}

FILES:${PN} += " \
    ${bindir}/setup-usb-serial-gadget \
    ${bindir}/setup-usb-mixed-audio-gadget \
    ${bindir}/setup-fixed-uac2.sh \
    ${bindir}/start-fixed-usb-audio.sh \
    ${bindir}/usb-audio-test.sh \
    ${bindir}/uac2-module-test.sh \
    ${bindir}/setup-usb-composite-gadget \
    ${bindir}/setup-usb-cdc-gadget \
    ${bindir}/setup-usb-audio-gadget \
    ${systemd_system_unitdir}/usb-composite-gadget-fixed.service \
"

FILES:${PN}:append:imx8mm-jaguar-dt510 = " \
    ${bindir}/setup-usb-dual-audio-gadget \
    ${systemd_system_unitdir}/usb-dual-audio-gadget-dt510.service \
"
