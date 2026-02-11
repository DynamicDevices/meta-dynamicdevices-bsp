FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"
FILESEXTRAPATHS:prepend:imx8mm-jaguar-sentai := "${THISDIR}/${PN}/imx8mm-jaguar-sentai:"

LICENSE = "GPL-3.0-or-later"
LIC_FILES_CHKSUM ?= "file://${COMMON_LICENSE_DIR}/GPL-3.0-or-later;md5=1c76c4cc354acaac30ed4d5eefea7245"

inherit systemd

SYSTEMD_SERVICE:${PN} = "board-init.service"
SYSTEMD_SERVICE:${PN}:imx8mm-jaguar-sentai = "board-init.service load-leds-lp50xx-early.service"
# Re-enabled for Phase 5.4 testing - Board init placeholder service (safe)
# SYSTEMD_AUTO_ENABLE:${PN} = "disable"

SRC_URI = "file://board-init.sh \
           file://board-init.service \
"

SRC_URI:append:imx8mm-jaguar-sentai = "file://leds-proof-of-life.sh file://load-leds-lp50xx-early.service file://load-leds-lp50xx-early.sh"
SRC_URI:append:imx8mm-jaguar-dt510 = "file://leds-proof-of-life.sh file://led-early-on.sh file://99-leds-early-on.rules"

do_install() {
  install -d ${D}${sbindir}
  install -m 755 ${WORKDIR}/*.sh ${D}${sbindir}
  install -d ${D}${systemd_unitdir}/system
  install -m 0644 ${WORKDIR}/board-init.service ${D}${systemd_unitdir}/system/board-init.service
}

do_install:append:imx8mm-jaguar-sentai() {
  install -m 0644 ${WORKDIR}/load-leds-lp50xx-early.service ${D}${systemd_unitdir}/system/
}
