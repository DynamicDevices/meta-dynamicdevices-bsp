SUMMARY = "Manual DT510 HDMI tests, console restore and driver recovery"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://dt510-hdmi-test \
    file://dt510-hdmi-recover \
    file://overscan-1920x1080.png \
    file://overscan-1920x1080.bgrx.gz;unpack=0 \
"

COMPATIBLE_MACHINE = "^imx8mm-jaguar-dt510$"
RDEPENDS:${PN} = "python3-core python3-fcntl python3-mmap python3-json python3-compression"

do_install() {
    install -d ${D}${sbindir} ${D}${datadir}/dt510-hdmi-test
    install -m 0755 ${WORKDIR}/dt510-hdmi-test ${D}${sbindir}/dt510-hdmi-test
    install -m 0755 ${WORKDIR}/dt510-hdmi-recover ${D}${sbindir}/dt510-hdmi-recover
    install -m 0644 ${WORKDIR}/overscan-1920x1080.png ${D}${datadir}/dt510-hdmi-test/
    install -m 0644 ${WORKDIR}/overscan-1920x1080.bgrx.gz ${D}${datadir}/dt510-hdmi-test/
}

FILES:${PN} = "${sbindir}/dt510-hdmi-test ${sbindir}/dt510-hdmi-recover ${datadir}/dt510-hdmi-test"
