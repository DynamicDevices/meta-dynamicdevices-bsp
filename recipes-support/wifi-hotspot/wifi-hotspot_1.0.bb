FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://setup-wifi-hotspot.sh"

do_install() {
  install -d ${D}${bindir}
  install -m 755 ${WORKDIR}/setup-wifi-hotspot.sh ${D}${bindir}
}

FILES:${PN} = "${bindir}/setup-wifi-hotspot.sh"

pkg_postinst_ontarget:${PN} () {
  #!/bin/sh
  echo Setting up WiFi Hotspot connectivity
  setup-wifi-hotspot.sh &
}
