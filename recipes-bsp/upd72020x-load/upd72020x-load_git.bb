DESCRIPTION = "Firmware loader for Renesas uPD72020x USB 3.0 chipsets for Linux"
HOMEPAGE = "https://github.com/markusj/upd72020x-load"

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

LICENSE = "LicenseRef-markusj-upd72020x-load"
LIC_FILES_CHKSUM = "file://${THISDIR}/${PN}/loader-upstream-license-note;md5=5d6ccd4600a48e87bfb1a9eaae80ad67"

inherit systemd

SYSTEMD_SERVICE:${PN} = "upd72020x-fwload.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

SRC_URI = "git://github.com/markusj/upd72020x-load;protocol=https;branch=master \
           file://01-patch-vendor-device-ids.patch \
"

PV = "1.0+git${SRCPV}"
SRCREV = "08c72d341abd1af93346122a8298fac59d2c1343"

S = "${WORKDIR}/git"

do_configure() {
}

do_compile () {
	oe_runmake
}

do_install () {
  install -d ${D}${sbindir}
  install -m 755 ${B}/upd72020x-load ${D}${sbindir}
  install -m 755 ${B}/upd72020x-check-and-init ${D}${sbindir}
  install -d ${D}${systemd_unitdir}/system
  install -m 0644 ${S}/systemd/upd72020x-fwload.service ${D}${systemd_unitdir}/system/upd72020x-fwload.service
}

RDEPENDS:${PN} = "bash"
