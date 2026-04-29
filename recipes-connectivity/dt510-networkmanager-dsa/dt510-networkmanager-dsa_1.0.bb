# SPDX-License-Identifier: MIT
SUMMARY = "NetworkManager: DT510 KSZ9896 DSA — DHCP on lan*, not end0 master"
DESCRIPTION = "Marks DSA master end0 unmanaged and adds a DHCP connection on lan1 \
(default). Set environment DT510_DSA_WIRED_IFACE on the service to use lan2–lan4."

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=083fadedef074be8699806d522d018711"

inherit systemd

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI = "file://dt510-dsa-master-unmanaged.conf \
           file://setup-dt510-lan1-connection.sh \
           file://setup-dt510-lan1-connection.service \
"

SYSTEMD_SERVICE:${PN} = "setup-dt510-lan1-connection.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

RDEPENDS:${PN} += "networkmanager bash"

do_install() {
	install -d ${D}${sysconfdir}/NetworkManager/conf.d
	install -m 0644 ${WORKDIR}/dt510-dsa-master-unmanaged.conf \
		${D}${sysconfdir}/NetworkManager/conf.d/

	install -d ${D}${bindir}
	install -m 0755 ${WORKDIR}/setup-dt510-lan1-connection.sh ${D}${bindir}/

	install -d ${D}${systemd_unitdir}/system
	install -m 0644 ${WORKDIR}/setup-dt510-lan1-connection.service \
		${D}${systemd_unitdir}/system/
}

FILES:${PN} += "${sysconfdir}/NetworkManager/conf.d ${bindir} ${systemd_unitdir}/system"
