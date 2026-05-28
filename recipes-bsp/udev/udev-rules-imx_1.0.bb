FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

DESCRIPTION = "udev rules for Freescale i.MX SOC based Jaguar boards"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

# Only apply udev rules for Dynamic Devices i.MX machines
SRC_URI:append:imx8mm-jaguar-sentai = " file://20-jaguar.rules"
SRC_URI:append:imx8mm-jaguar-dt510 = " \
    file://imx8mm-jaguar-dt510/20-jaguar.rules \
    file://imx8mm-jaguar-dt510/99-dt510-gnss.rules \
    file://imx8mm-jaguar-dt510/99-dt510-etm.rules \
    file://imx8mm-jaguar-dt510/99-dt510-ovd485.rules \
"
SRC_URI:append:imx8mm-jaguar-inst = " file://20-jaguar.rules"
SRC_URI:append:imx8mm-jaguar-handheld = " file://20-jaguar.rules"
SRC_URI:append:imx8mm-jaguar-phasora = " file://20-jaguar.rules"
SRC_URI:append:imx93-jaguar-eink = " file://20-jaguar.rules"

S = "${WORKDIR}"

do_install () {
	install -d ${D}${sysconfdir}/udev/rules.d
	# imx8mm-jaguar-dt510 uses a subdir in SRC_URI (see FILESEXTRAPATHS / fetch layout).
	if [ -f ${WORKDIR}/imx8mm-jaguar-dt510/20-jaguar.rules ]; then
		install -m 0644 ${WORKDIR}/imx8mm-jaguar-dt510/20-jaguar.rules ${D}${sysconfdir}/udev/rules.d/
	else
		install -m 0644 ${WORKDIR}/20-jaguar.rules ${D}${sysconfdir}/udev/rules.d/
	fi
}

do_install:append:imx8mm-jaguar-dt510() {
	install -m 0644 ${WORKDIR}/imx8mm-jaguar-dt510/99-dt510-gnss.rules ${D}${sysconfdir}/udev/rules.d/
	install -m 0644 ${WORKDIR}/imx8mm-jaguar-dt510/99-dt510-etm.rules ${D}${sysconfdir}/udev/rules.d/
	install -m 0644 ${WORKDIR}/imx8mm-jaguar-dt510/99-dt510-ovd485.rules ${D}${sysconfdir}/udev/rules.d/
}
