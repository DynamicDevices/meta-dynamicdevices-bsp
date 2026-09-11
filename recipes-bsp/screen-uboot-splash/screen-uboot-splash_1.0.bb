SUMMARY = "Active-Edge U-Boot splash artwork"
DESCRIPTION = "Deploys machine-native Active-Edge BMP derivatives into the boot filesystem"
LICENSE = "CLOSED"

SRC_URI = " \
    file://active-edge-splash-1200x1920.bmp \
    file://active-edge-splash-1280x720.bmp \
"

S = "${WORKDIR}"

inherit deploy

do_deploy() {
    install -Dm 0644 ${WORKDIR}/active-edge-splash-1200x1920.bmp \
        ${DEPLOYDIR}/active-edge-splash-1200x1920.bmp
    install -Dm 0644 ${WORKDIR}/active-edge-splash-1280x720.bmp \
        ${DEPLOYDIR}/active-edge-splash-1280x720.bmp
}

addtask deploy before do_build after do_unpack
