FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit systemd

SYSTEMD_SERVICE:${PN} = "setup-default-connections.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

SRC_URI = "file://setup-default-connections.sh \
           file://setup-default-connections.service \
"

do_install() {
  install -d ${D}${bindir}
  install -m 755 ${WORKDIR}/setup-default-connections.sh ${D}${bindir}
  install -d ${D}${systemd_unitdir}/system 	
  install -m 0644 ${WORKDIR}/setup-default-connections.service ${D}${systemd_unitdir}/system/setup-default-connections.service
}

FILES:${PN} = "${bindir}/setup-default-connections.sh ${systemd_unitdir}/system/setup-default-connections.service"

