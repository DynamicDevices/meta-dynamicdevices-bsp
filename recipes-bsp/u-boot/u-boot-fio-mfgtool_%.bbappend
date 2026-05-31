FILESEXTRAPATHS:prepend := "${THISDIR}/u-boot-fio:"

SRC_URI:append:imx95-frdm-evk = " \
    file://0001-kconfig-imx95-secondary-boot-sector-offset.patch \
    file://custom-dtb.cfg \
    file://mfgtool-fastboot.cfg \
    file://fix-environment-config.cfg \
    file://imx95-15x15-frdm.dts \
    file://imx95-15x15-frdm-u-boot.dtsi \
"

# u-boot-fio imx-2024.04 has imx95_15x15_evk_defconfig only; FRDM DTB is not upstream yet.
do_configure:prepend:imx95-frdm-evk() {
    rm -rf ${S}/include/config ${S}/.config
}

do_configure:append:imx95-frdm-evk() {
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
