FILESEXTRAPATHS:prepend := "${THISDIR}/u-boot-fio:"

SRC_URI:append:imx95-frdm-evk = " \
    file://0001-kconfig-imx95-secondary-boot-sector-offset.patch \
    file://custom-dtb.cfg \
    file://mfgtool-fastboot.cfg \
    file://fix-environment-config.cfg \
"
