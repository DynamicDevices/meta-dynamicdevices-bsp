SUMMARY = "AESL artwork for the DT510 U-Boot HDMI splash"
DESCRIPTION = "720p BMP derived from the existing canonical AESL screen artwork"
LICENSE = "CLOSED"
COMPATIBLE_MACHINE = "^imx8mm-jaguar-dt510$"
PACKAGE_ARCH = "${MACHINE_ARCH}"

SRC_URI = "file://active-edge-splash-1920x1200.png file://make-splash.py"
DEPENDS = "python3-pillow-native"
S = "${WORKDIR}"
B = "${WORKDIR}/build"

inherit deploy python3native

do_compile[dirs] = "${B}"
do_compile() {
    ${PYTHON} ${WORKDIR}/make-splash.py \
        ${WORKDIR}/active-edge-splash-1920x1200.png \
        ${B}/active-edge-splash-1280x720.bmp
}

do_deploy() {
    install -m 0644 ${B}/active-edge-splash-1280x720.bmp ${DEPLOYDIR}/
}
addtask deploy before do_build after do_compile
