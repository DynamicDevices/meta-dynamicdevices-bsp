FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# Belt-and-suspenders when DISTRO_FEATURES modsign is off but kernel metadata still
# enables CONFIG_MODULE_SIG (factory-keys / modsign_key.pem not present locally).
SRC_URI:append = "${@' file://disable-modsign.cfg' if (d.getVar('LOCAL_DEVELOPMENT_BUILD') or '0') == '1' or (d.getVar('MODSIGN_ENABLE') or '1') == '0' or (d.getVar('MODSIGN') or '1') == '0' else ''}"

# lmp-kernel-cache has imx93 BSP metadata only; imx95 FRDM is not upstream yet.
SRC_URI:append:imx95-frdm-evk = " \
    file://imx95-15x15-lpddr4x-frdm.scc \
    file://imx95-15x15-lpddr4x-frdm-standard.scc \
    file://imx95-15x15-lpddr4x-frdm.cfg \
    file://imx95-15x15-frdm.dts \
"

do_kernel_metadata:prepend:imx95-frdm-evk() {
    install -d ${WORKDIR}/kernel-meta/bsp/imx
    install -m 0644 ${WORKDIR}/imx95-15x15-lpddr4x-frdm.scc \
        ${WORKDIR}/imx95-15x15-lpddr4x-frdm-standard.scc \
        ${WORKDIR}/imx95-15x15-lpddr4x-frdm.cfg \
        ${WORKDIR}/kernel-meta/bsp/imx/
}

# linux-lmp-fslc-imx 6.6.52 has imx95.dtsi but not imx95-15x15-frdm.dts (mainline Jan 2026).
do_configure:append:imx95-frdm-evk() {
    if [ -f ${WORKDIR}/imx95-15x15-frdm.dts ]; then
        install -D -m 0644 ${WORKDIR}/imx95-15x15-frdm.dts ${S}/arch/arm64/boot/dts/freescale/
        if ! grep -q 'imx95-15x15-frdm.dtb' ${S}/arch/arm64/boot/dts/freescale/Makefile; then
            printf '\ndtb-$(CONFIG_ARCH_MXC) += imx95-15x15-frdm.dtb\n' \
                >> ${S}/arch/arm64/boot/dts/freescale/Makefile
        fi
    else
        bbwarn "imx95-15x15-frdm.dts missing in ${WORKDIR}"
    fi
}
