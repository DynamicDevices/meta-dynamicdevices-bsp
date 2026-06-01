FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

inherit lmp-signing-override

require ${THISDIR}/u-boot-fio/imx95-frdm-evk.inc

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

FILESEXTRAPATHS:prepend:imx95-frdm-evk := "${THISDIR}/u-boot-fio/imx95-frdm-evk:"

SRC_URI:append:imx95-frdm-evk = " \
    file://custom-dtb.cfg \
    file://imx95-spl-scmi.cfg \
    file://fix-environment-config.cfg \
    file://0002-skip-srctree-clean-check-out-of-tree.patch \
    file://0003-arm-dts-add-imx95-15x15-frdm-dtb.patch \
    file://imx95-15x15-frdm.dts;subdir=git/arch/arm/dts \
    file://imx95-15x15-frdm-u-boot.dtsi;subdir=git/arch/arm/dts \
"

# Factory -j16 can race u-boot's test -e on CONFIG_DEFAULT_DEVICE_TREE vs DTB builds.
PARALLEL_MAKE:imx95-frdm-evk = "-j 1"

# Factory SPL links image-container.o against check_secondary_cnt_set; in soc.c it
# was under #ifdef CONFIG_IMX95. Close the ifdef before the stub (no quilt patch:
# Foundries rejects fuzz on soc.c line drift between u-boot-fio and mfgtool).
do_patch:append:imx95-frdm-evk() {
    soc="${S}/arch/arm/mach-imx/imx9/scmi/soc.c"
    if [ ! -f "$soc" ]; then
        bbfatal "imx95-frdm-evk: missing ${soc}"
    fi
    if grep -q 'imx95-frdm-evk: check_secondary export fix applied' "$soc"; then
        return
    fi
    awk '
        /^#ifdef CONFIG_IMX95$/ { imx95 = 1 }
        imx95 && /^bool check_secondary_cnt_set/ && !done {
            print "#endif"
            print ""
            done = 1
        }
        imx95 && done && /^#endif$/ { imx95 = 0; next }
        { print }
        END {
            if (!done)
                exit 1
        }
    ' "$soc" > "$soc.tmp" || bbfatal "imx95-frdm-evk: soc.c check_secondary fix failed"
    echo "/* imx95-frdm-evk: check_secondary export fix applied */" >> "$soc.tmp"
    mv "$soc.tmp" "$soc"
}

# TODO: Add u-boot DTB customisation patch
#SRC_URI:append:imx8ulp-lpddr4-evk = " \
#    file://custom-dtb.cfg \
#"
