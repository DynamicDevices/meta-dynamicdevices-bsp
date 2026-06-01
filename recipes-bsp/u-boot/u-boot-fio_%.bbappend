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

# u-boot-fio do_patch is finalized as Python — patch soc.c here (shell/awk failed in CI).
python do_patch:append:imx95-frdm-evk() {
    import os

    soc = os.path.join(d.getVar('S'), 'arch/arm/mach-imx/imx9/scmi/soc.c')
    if not os.path.isfile(soc):
        bb.fatal('imx95-frdm-evk: missing %s' % soc)

    marker = 'imx95-frdm-evk: check_secondary export fix applied'
    with open(soc, 'r', encoding='utf-8', errors='replace') as f:
        lines = f.readlines()
    if any(marker in line for line in lines):
        return

    out = []
    imx95 = False
    done = False
    for line in lines:
        if line.strip() == '#ifdef CONFIG_IMX95':
            imx95 = True
        if imx95 and not done and 'check_secondary_cnt_set' in line:
            out.append('#endif\n')
            out.append('\n')
            done = True
        if imx95 and done and line.strip() == '#endif':
            imx95 = False
            continue
        out.append(line)

    if not done:
        bb.fatal('imx95-frdm-evk: check_secondary_cnt_set not found in %s' % soc)

    out.append('/* %s */\n' % marker)
    with open(soc, 'w', encoding='utf-8') as f:
        f.writelines(out)
}

# Factory only: prebuild FRDM DTB before -j16 races CONFIG_DEFAULT_DEVICE_TREE (mfgtool uses evk O=).
do_compile:prepend:imx95-frdm-evk() {
    imx95_frdm_uboot_scrub_srctree
    for config in ${UBOOT_MACHINE}; do
        bbnote "imx95-frdm-evk: prebuild imx95-15x15-frdm.dtb (O=${B}/${config})"
        oe_runmake -C ${S} O=${B}/${config} arch/arm/dts/imx95-15x15-frdm.dtb
    done
}

# TODO: Add u-boot DTB customisation patch
#SRC_URI:append:imx8ulp-lpddr4-evk = " \
#    file://custom-dtb.cfg \
#"
