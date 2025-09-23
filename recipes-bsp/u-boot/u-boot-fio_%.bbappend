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

# Production U-Boot configuration (exclude mfgtool builds)
SRC_URI:append:imx93-jaguar-eink = " \
    ${@bb.utils.contains('DISTRO', 'lmp-mfgtool', '', 'file://custom-dtb.cfg', d)} \
    ${@bb.utils.contains('DISTRO', 'lmp-mfgtool', '', 'file://enable-i2c.cfg', d)} \
    ${@bb.utils.contains('DISTRO', 'lmp-mfgtool', '', 'file://enable-spi.cfg', d)} \
    ${@bb.utils.contains('DISTRO', 'lmp-mfgtool', '', 'file://enable-fiovb.cfg', d)} \
    ${@bb.utils.contains('DISTRO', 'lmp-mfgtool', '', 'file://disable-unused-peripherals.cfg', d)} \
    ${@bb.utils.contains('DISTRO', 'lmp-mfgtool', '', 'file://disable-ele-reset.cfg', d)} \
    ${@bb.utils.contains('ENABLE_BOOT_PROFILING', '1', 'file://enable_boot_profiling.cfg', '', d)} \
"

# TODO: Add u-boot DTB customisation patch
#SRC_URI:append:imx8ulp-lpddr4-evk = " \
#    file://custom-dtb.cfg \
#"

