# DT510: imx8mm-evk.dtsi zb_mux defaults target spidev1.0 + gpiochip5 sideband.
# Jaguar DT510 wires Zigbee on ECSPI1 (/dev/spidev0.0) and ZB_INT on GPIO4_IO22 (/dev/gpiochip3).

FILESEXTRAPATHS:prepend:imx8mm-jaguar-dt510 := "${THISDIR}/files:"
SRC_URI:append:imx8mm-jaguar-dt510 = " file://zb_mux.sh "

do_install:append:imx8mm-jaguar-dt510() {
	install -m 0755 ${WORKDIR}/zb_mux.sh ${D}${sbindir}/zb_mux.sh
}
