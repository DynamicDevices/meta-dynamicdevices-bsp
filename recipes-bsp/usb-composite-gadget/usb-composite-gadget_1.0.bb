SUMMARY = "USB Composite Gadget for imx8mm-jaguar-sentai"
DESCRIPTION = "USB composite gadget service providing CDC ACM serial and UAC2 audio interfaces for bidirectional communication with host computer"
LICENSE = "GPL-3.0-or-later"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-3.0-or-later;md5=1c76c4cc354acaac30ed4d5eefea7245"

SRC_URI = " \
    file://setup-usb-composite-gadget \
    file://usb-composite-gadget.service \
    file://docker-service-override.conf \
"

S = "${WORKDIR}"

RDEPENDS:${PN} = "systemd"

inherit systemd

SYSTEMD_SERVICE:${PN} = "usb-composite-gadget.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    # Install USB composite gadget setup script
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/setup-usb-composite-gadget ${D}${bindir}/

    # Install systemd service for USB composite gadget
    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${WORKDIR}/usb-composite-gadget.service ${D}${systemd_unitdir}/system/

    # Install Docker service override for dependency management
    install -d ${D}${sysconfdir}/systemd/system/docker.service.d
    install -m 0644 ${WORKDIR}/docker-service-override.conf ${D}${sysconfdir}/systemd/system/docker.service.d/usb-gadget-dependency.conf
}

FILES:${PN} = " \
    ${bindir}/setup-usb-composite-gadget \
    ${systemd_unitdir}/system/usb-composite-gadget.service \
    ${sysconfdir}/systemd/system/docker.service.d/usb-gadget-dependency.conf \
"

# Only install on imx8mm-jaguar machines with USB gadget support
COMPATIBLE_MACHINE = "(imx8mm-jaguar-sentai|imx8mm-jaguar-dt510)"
