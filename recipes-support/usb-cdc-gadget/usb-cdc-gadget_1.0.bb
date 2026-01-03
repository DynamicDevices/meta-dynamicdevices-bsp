SUMMARY = "USB CDC Serial Gadget setup script for imx8mm-jaguar-sentai"
DESCRIPTION = "Provides script to configure the board as a USB CDC ACM serial device for debugging"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://setup-usb-cdc-gadget.sh"

S = "${WORKDIR}"

RDEPENDS:${PN} = ""

# Only install on machines with USB gadget support
COMPATIBLE_MACHINE = "(imx8mm-jaguar-sentai|imx8mm-jaguar-dt510)"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/setup-usb-cdc-gadget.sh ${D}${bindir}/setup-usb-cdc-gadget
}

FILES:${PN} = "${bindir}/setup-usb-cdc-gadget"
