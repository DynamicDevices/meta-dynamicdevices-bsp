# Shared imx95-frdm-evk hooks for u-boot-fio and u-boot-fio-mfgtool.
# Out-of-tree build (O=${B}): configure can leave include/config in ${S}; patch
# 0002-skip-srctree-clean-check-out-of-tree.patch removes the prepare guard.

imx95_frdm_uboot_scrub_source() {
    bbnote "imx95-frdm-evk: scrub stale u-boot config in ${S} (O=${B})"
    rm -rf ${S}/include/config ${S}/.config
}

imx95_frdm_uboot_install_dts() {
    if [ -f ${WORKDIR}/imx95-15x15-frdm.dts ]; then
        install -D -m 0644 ${WORKDIR}/imx95-15x15-frdm.dts ${S}/arch/arm/dts/
        install -D -m 0644 ${WORKDIR}/imx95-15x15-frdm-u-boot.dtsi ${S}/arch/arm/dts/
        if ! grep -q 'imx95-15x15-frdm.dtb' ${S}/arch/arm/dts/Makefile; then
            sed -i '/imx95-15x15-evk.dtb/a imx95-15x15-frdm.dtb \\' ${S}/arch/arm/dts/Makefile
        fi
    else
        bbwarn "imx95-15x15-frdm.dts missing in ${WORKDIR}"
    fi
}

do_configure:prepend:imx95-frdm-evk() {
    imx95_frdm_uboot_scrub_source
}

do_configure:append:imx95-frdm-evk() {
    imx95_frdm_uboot_install_dts
}

do_compile:prepend:imx95-frdm-evk() {
    imx95_frdm_uboot_scrub_source
}
