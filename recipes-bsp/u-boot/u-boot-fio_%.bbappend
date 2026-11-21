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
    ${@bb.utils.contains('MACHINE_FEATURES', 'hdmi-boot-splash', 'file://02-dt510-lt9611-splash.patch file://03-dt510-reserved-display-handover.patch file://lt9611-dt510.c file://dt510-hdmi.dtsi file://imx8mm-jaguar-dt510-uboot.dts file://imx8mm-jaguar-dt510-uboot-u-boot.dtsi file://hdmi-splash.cfg', '', d)} \
"

do_configure:prepend:imx8mm-jaguar-dt510() {
    if ${@bb.utils.contains('MACHINE_FEATURES', 'hdmi-boot-splash', 'true', 'false', d)}; then
        install -m 0644 ${WORKDIR}/lt9611-dt510.c ${S}/drivers/video/lt9611-dt510.c
        install -m 0644 ${WORKDIR}/dt510-hdmi.dtsi ${S}/arch/arm/dts/dt510-hdmi.dtsi
        install -m 0644 ${WORKDIR}/imx8mm-jaguar-dt510-uboot.dts ${S}/arch/arm/dts/
        install -m 0644 ${WORKDIR}/imx8mm-jaguar-dt510-uboot-u-boot.dtsi ${S}/arch/arm/dts/
    fi
}


SRC_URI:append:imx8mm-jaguar-inst = " \
    file://custom-dtb.cfg \
    file://01-customise-dtb.patch \
"
SRC_URI:append:imx8mm-jaguar-screen = " \
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

# TODO: Add u-boot DTB customisation patch
#SRC_URI:append:imx8ulp-lpddr4-evk = " \
#    file://custom-dtb.cfg \
#"

