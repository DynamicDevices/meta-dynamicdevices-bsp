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

	# Tarball default references /usr/bin/simple_gw (not installed; sample GW binary is simple_gw_zc).
	# OTA server path defaults under /usr/share/zboss which is not writable on typical LmP rootfs.
	if [ -f "${D}${sysconfdir}/default/zb_app.env" ]; then
		sed -i 's/^ZB_APP_NAME=simple_gw$/ZB_APP_NAME=simple_gw_zc/' "${D}${sysconfdir}/default/zb_app.env"
		sed -i 's|^ZBOSS_OTA_SERVER_DIR=.*|ZBOSS_OTA_SERVER_DIR=/var/local/zboss/ota-server-files|' "${D}${sysconfdir}/default/zb_app.env"
	fi
}
