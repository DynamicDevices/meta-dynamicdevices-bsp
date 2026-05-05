# DT510-only Zigbee mux launcher (imx8mm-jaguar-dt510).
#
# imx8mm-evk zb_mux defaults use spidev1.0 + gpiochip5; Jaguar DT510 uses ECSPI1
# (/dev/spidev0.0) and ZB_INT on GPIO4_IO22 (/dev/gpiochip3 line 22).
#
# Scoped with :imx8mm-jaguar-dt510 on every directive — imx8mm-jaguar-sentai and all
# other machines keep the unmodified zigbee-rcp-sdk tarball install (no FILESEXTRAPATHS,
# no extra SRC_URI, no do_install append).

FILESEXTRAPATHS:prepend:imx8mm-jaguar-dt510 := "${THISDIR}/files:"
SRC_URI:append:imx8mm-jaguar-dt510 = " file://zb_mux.sh "

do_install:append:imx8mm-jaguar-dt510() {
	install -m 0755 ${WORKDIR}/zb_mux.sh ${D}${sbindir}/zb_mux.sh
}
