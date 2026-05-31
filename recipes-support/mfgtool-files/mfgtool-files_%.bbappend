FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# meta-lmp do_deploy_prepend_mx8() only runs for mx8, not mx95 — deploy imx-boot-mfgtool here.
do_deploy:prepend:mx95-nxp-bsp() {
    install -d ${DEPLOYDIR}/${PN}
    install -m 0644 ${DEPLOY_DIR_IMAGE}/imx-boot ${DEPLOYDIR}/${PN}/imx-boot-mfgtool
    install -m 0644 ${DEPLOY_DIR_IMAGE}/u-boot.itb ${DEPLOYDIR}/${PN}/u-boot-mfgtool.itb
    install -m 0644 ${DEPLOY_DIR_IMAGE}/fitImage-${INITRAMFS_IMAGE}-${MACHINE}-${MACHINE} \
        ${DEPLOYDIR}/${PN}/fitImage-${MACHINE}-mfgtool
}

def get_do_deploy_depends_mx95(d):
    if 'mx95-nxp-bsp' in (d.getVar('MACHINEOVERRIDES') or '').split(':'):
        return " imx-boot:do_deploy"
    return ""

do_deploy[depends] += "${@get_do_deploy_depends_mx95(d)}"
