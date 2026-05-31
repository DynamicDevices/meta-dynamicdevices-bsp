# Shared imx95-frdm-evk hooks for u-boot-fio and u-boot-fio-mfgtool.
# Out-of-tree build (O=${B}/${UBOOT_MACHINE}): configure leaves include/config
# in ${S}; patch 0002-skip-srctree-clean-check-out-of-tree.patch removes the
# prepare guard. FRDM DTS is not upstream in u-boot-fio imx-2024.04 yet.

imx95_frdm_uboot_scrub_source() {
    bbnote "imx95-frdm-evk: scrub stale u-boot config in ${S} (O=${B})"
    rm -rf ${S}/include/config ${S}/.config
}

imx95_frdm_uboot_install_dts() {
    if [ -f ${WORKDIR}/imx95-15x15-frdm.dts ]; then
        install -D -m 0644 ${WORKDIR}/imx95-15x15-frdm.dts ${S}/arch/arm/dts/
        install -D -m 0644 ${WORKDIR}/imx95-15x15-frdm-u-boot.dtsi ${S}/arch/arm/dts/
    else
        bbwarn "imx95-15x15-frdm.dts missing in ${WORKDIR}"
    fi
}

imx95_frdm_uboot_prebuild_dtb() {
    if [ -n "${UBOOT_CONFIG}" ]; then
        for config in ${UBOOT_MACHINE}; do
            bbnote "imx95-frdm-evk: prebuild imx95-15x15-frdm.dtb (O=${B}/${config})"
            oe_runmake -C ${S} O=${B}/${config} arch/arm/dts/imx95-15x15-frdm.dtb
        done
    else
        bbnote "imx95-frdm-evk: prebuild imx95-15x15-frdm.dtb (O=${B})"
        oe_runmake -C ${S} O=${B} arch/arm/dts/imx95-15x15-frdm.dtb
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
    imx95_frdm_uboot_install_dts
    # Factory builds use -j16; u-boot's test -e on CONFIG_DEFAULT_DEVICE_TREE can
    # run before imx95-15x15-frdm.dtb finishes when many DTBs build in parallel.
    # oe_runmake must pass O=${B}/${UBOOT_MACHINE}: plain oe_runmake has no O= and
    # CONFIG_ARCH_IMX9 dtbs are not in the make target list.
    imx95_frdm_uboot_prebuild_dtb
}
