SUMMARY = "Active-Edge U-Boot splash artwork"
DESCRIPTION = "Deploys the native, pre-rotated Jaguar Screen BMP into the boot filesystem"
LICENSE = "CLOSED"

SRC_URI = "file://active-edge-splash-1200x1920.bmp"

S = "${WORKDIR}"

inherit deploy

do_deploy() {
    install -Dm 0644 ${WORKDIR}/active-edge-splash-1200x1920.bmp \
        ${DEPLOYDIR}/active-edge-splash-1200x1920.bmp
}

addtask deploy before do_build after do_unpack
