FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit systemd

SYSTEMD_SERVICE:${PN} = "board-init.service"
# Re-enabled for Phase 5.4 testing - Board init placeholder service (safe)
# SYSTEMD_AUTO_ENABLE:${PN} = "disable"

SRC_URI = "file://board-init.sh \
           file://board-init.service \
"

do_install() {
  install -d ${D}${sbindir}
  install -m 755 ${WORKDIR}/*.sh ${D}${sbindir}
  install -d ${D}${systemd_unitdir}/system 	
  install -m 0644 ${WORKDIR}/board-init.service ${D}${systemd_unitdir}/system/board-init.service
}

