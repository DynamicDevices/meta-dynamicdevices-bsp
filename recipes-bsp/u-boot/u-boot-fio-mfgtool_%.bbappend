FILESEXTRAPATHS:prepend := "${THISDIR}/u-boot-fio:"

require ${THISDIR}/u-boot-fio/imx95-frdm-evk.inc

FILESEXTRAPATHS:prepend:imx95-frdm-evk := "${THISDIR}/u-boot-fio/imx95-frdm-evk:"

SRC_URI:append:imx95-frdm-evk = " \
    file://0001-kconfig-imx95-secondary-boot-sector-offset.patch \
    file://0002-skip-srctree-clean-check-out-of-tree.patch \
    file://0003-arm-dts-add-imx95-15x15-frdm-dtb.patch \
    file://0004-imx9-spl-stub-check-secondary-cnt-set.patch \
    file://custom-dtb.cfg \
    file://mfgtool-fastboot.cfg \
    file://fix-environment-config.cfg \
    file://imx95-15x15-frdm.dts;subdir=git/arch/arm/dts \
    file://imx95-15x15-frdm-u-boot.dtsi;subdir=git/arch/arm/dts \
"

PARALLEL_MAKE:imx95-frdm-evk = "-j 1"
