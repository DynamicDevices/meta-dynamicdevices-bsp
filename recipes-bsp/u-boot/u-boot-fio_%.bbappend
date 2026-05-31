FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

inherit lmp-signing-override

SRC_URI:append:imx8mm-jaguar-sentai = " \
    file://custom-dtb.cfg \
    file://01-customise-dtb.patch \
    file://enable-i2c.cfg \
    file://disable-se050-debug.cfg \
    file://uart4-rdc-assignment.cfg \
    ${@bb.utils.contains('ENABLE_BOOT_PROFILING', '1', 'file://enable_boot_profiling.cfg', '', d)} \
"

SRC_URI:append:imx8mm-jaguar-dt510 = " \
    file://custom-dtb.cfg \
    file://01-customise-dtb.patch \
    file://enable-i2c.cfg \
    file://disable-se050-debug.cfg \
    file://uart4-rdc-assignment.cfg \
    ${@bb.utils.contains('ENABLE_BOOT_PROFILING', '1', 'file://enable_boot_profiling.cfg', '', d)} \
"

SRC_URI:append:imx8mm-jaguar-inst = " \
    file://custom-dtb.cfg \
    file://01-customise-dtb.patch \
"

SRC_URI:append:imx8mm-jaguar-handheld = " \
    file://custom-dtb.cfg \
    file://01-customise-dtb.patch \
"

SRC_URI:append:imx8mm-jaguar-phasora = " \
    file://custom-dtb.cfg \
    file://01-customise-dtb.patch \
    file://enable-i2c.cfg \
    file://enable-pci.cfg \
    file://boot.cmd \
"

SRC_URI:append:imx93-jaguar-eink = " \
    file://custom-dtb.cfg \
    file://enable-pmic.cfg \
    file://enable-rtc.cfg \
"

SRC_URI:append:imx95-frdm-evk = " \
    file://custom-dtb.cfg \
    file://fix-environment-config.cfg \
    file://imx95-15x15-frdm.dts \
"

do_configure:append:imx95-frdm-evk() {
    if [ -f ${WORKDIR}/imx95-15x15-frdm.dts ]; then
        install -D -m 0644 ${WORKDIR}/imx95-15x15-frdm.dts ${S}/arch/arm/dts/
        if ! grep -q 'imx95-15x15-frdm.dtb' ${S}/arch/arm/dts/Makefile; then
            sed -i '/imx95-15x15-evk.dtb/a imx95-15x15-frdm.dtb \\' ${S}/arch/arm/dts/Makefile
        fi
    else
        bbwarn "imx95-15x15-frdm.dts missing in ${WORKDIR}"
    fi
}

# TODO: Add u-boot DTB customisation patch
#SRC_URI:append:imx8ulp-lpddr4-evk = " \
#    file://custom-dtb.cfg \
#"

