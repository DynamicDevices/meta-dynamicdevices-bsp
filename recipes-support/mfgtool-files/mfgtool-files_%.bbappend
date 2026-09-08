FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append:imx95-frdm-evk = " \
    file://verify_image.uuu.in \
    file://README-imx95-mfgtool.md \
"

do_compile:append:imx95-frdm-evk() {
    sed -e 's/@@MACHINE@@/${MACHINE}/' \
        -e 's/@@MFGTOOL_FLASH_IMAGE@@/${MFGTOOL_FLASH_IMAGE}/' \
        -e 's/@@IMAGE_NAME_SUFFIX@@/${IMAGE_NAME_SUFFIX}/' \
        ${S}/verify_image.uuu.in > verify_image.uuu
}

# meta-lmp only deploys an i.MX manufacturing boot container for mx8/mx93.
# i.MX95 must use flash_all: falling back to the production imx-boot produces a
# plausible-looking bundle which cannot complete the ROM/SPL UUU transitions.
do_deploy:prepend:imx95-frdm-evk() {
    install -d ${DEPLOYDIR}/${PN}
    install -m 0644 "${DEPLOY_DIR_IMAGE}/imx-boot-${MACHINE}-sd.bin-flash_all" \
        ${DEPLOYDIR}/${PN}/imx-boot-mfgtool
    install -m 0644 ${DEPLOY_DIR_IMAGE}/u-boot.itb ${DEPLOYDIR}/${PN}/u-boot-mfgtool.itb
    install -m 0644 ${DEPLOY_DIR_IMAGE}/fitImage-${INITRAMFS_IMAGE}-${MACHINE}-${MACHINE} \
        ${DEPLOYDIR}/${PN}/fitImage-${MACHINE}-mfgtool
    install -m 0644 ${WORKDIR}/verify_image.uuu ${DEPLOYDIR}/${PN}
    install -m 0644 ${WORKDIR}/README-imx95-mfgtool.md ${DEPLOYDIR}/${PN}/README.md
}

def get_do_deploy_depends_mx95(d):
    if d.getVar('MACHINE') == 'imx95-frdm-evk':
        return " imx-boot:do_deploy"
    return ""

do_deploy[depends] += "${@get_do_deploy_depends_mx95(d)}"
