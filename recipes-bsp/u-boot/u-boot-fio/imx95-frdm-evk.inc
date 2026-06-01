# imx95-frdm-evk: shared u-boot-fio / u-boot-fio-mfgtool hooks.
#
# Out-of-tree build (O=${B}/${UBOOT_MACHINE}). Patch 0002 drops the srctree-clean
# guard; configure can still leave .config under ${S} — scrub before configure/compile.
# FRDM DTS is not in upstream u-boot-fio imx-2024.04; ship via SRC_URI subdir= below.

imx95_frdm_uboot_scrub_srctree() {
    rm -rf ${S}/include/config ${S}/.config
}

do_configure:prepend:imx95-frdm-evk() {
    imx95_frdm_uboot_scrub_srctree
}
