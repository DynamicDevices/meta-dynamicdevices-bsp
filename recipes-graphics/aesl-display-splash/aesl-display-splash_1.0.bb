SUMMARY = "Common AESL artwork for the Linux boot splash and desktop"
LICENSE = "CLOSED"
PACKAGE_ARCH = "${MACHINE_ARCH}"

# Share the exact canonical input/generator with the confirmed U-Boot artwork.
FILESEXTRAPATHS:prepend := "${THISDIR}/../../recipes-bsp/dt510-hdmi-splash/files:"
SRC_URI = "file://active-edge-splash-1920x1200.png file://make-splash.py file://make-linux-splash.py"
DEPENDS = "python3-pillow-native"
inherit python3native features_check
REQUIRED_DISTRO_FEATURES = "display-boot-splash"
S = "${WORKDIR}"
B = "${WORKDIR}/build"

do_compile[dirs] = "${B}"
do_compile() {
    ${PYTHON} ${WORKDIR}/make-linux-splash.py ${MACHINE} ${WORKDIR}/active-edge-splash-1920x1200.png ${B}/splash.png ${B}/psplash.png
}

do_install() {
    install -d ${D}${datadir}/aesl-display-splash
    install -m 0644 ${B}/splash.png ${D}${datadir}/aesl-display-splash/splash.png
    touch ${D}${datadir}/aesl-display-splash/retain-until-weston
}
