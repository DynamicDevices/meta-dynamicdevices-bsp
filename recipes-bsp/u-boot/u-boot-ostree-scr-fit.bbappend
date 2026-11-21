FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

inherit lmp-signing-override

# OSTree OTA can retain the previous deployment's kernel arguments. Apply only
# the display policy in RAM, after rollback selection and before root is added.
# Never rewrite uEnv.txt, save the environment, or change deployment selection.
SRC_URI:append = " ${@bb.utils.contains('DISTRO_FEATURES', 'display-boot-splash', 'file://display-bootargs.cmd', '', d)}"

python do_unpack:append() {
    from pathlib import Path
    # Do not return from an append: later machine appends must still run when
    # display-boot-splash is disabled (including DT510's splash marker removal).
    if bb.utils.contains('DISTRO_FEATURES', 'display-boot-splash', True, False, d):
        work = Path(d.getVar('WORKDIR'))
        footer = work / 'boot-footer.cmd.in'
        text = footer.read_text()
        marker = 'run bootcmd_rollback\n'
        if text.count(marker) != 1:
            bb.fatal('Display boot policy requires exactly one rollback selection')
        policy = (work / 'display-bootargs.cmd').read_text()
        mode = ' video=HDMI-A-1:1280x720@60e' if d.getVar('MACHINE') == 'imx8mm-jaguar-dt510' else ''
        policy = policy.replace('@@AESL_DISPLAY_MODE@@', mode)
        footer.write_text(text.replace(marker, marker + policy + '\n'))
}
do_unpack[vardeps] += "DISTRO_FEATURES MACHINE"

SRC_URI:append:imx8mm-jaguar-sentai = " \
    file://boot.cmd \
"

SRC_URI:append:imx8mm-jaguar-dt510 = " \
    file://boot.cmd \
    ${@bb.utils.contains('MACHINE_FEATURES', 'hdmi-boot-splash', 'file://hdmi-splash.cmd', '', d)} \
"

# Append after the common header resolves image_dir_path/ostree_bootpart. An
# OTA updates boot firmware in the deployment, not arbitrary FAT-root files.
# Both inputs are freshly unpacked when feature metadata changes.
python do_unpack:append:imx8mm-jaguar-dt510() {
    from pathlib import Path
    source = Path(d.getVar('WORKDIR')) / 'boot.cmd'
    marker = '@@DT510_HDMI_SPLASH@@\n'
    text = source.read_text()
    if text.count(marker) != 1:
        bb.fatal('DT510 splash marker missing or duplicated')
    enabled = bb.utils.contains('MACHINE_FEATURES', 'hdmi-boot-splash', True, False, d)
    source.write_text(text.replace(marker, ''))
    if enabled:
        header = source.parent / 'boot-header.cmd.in'
        original = header.read_text()
        fragment = (source.parent / 'hdmi-splash.cmd').read_text()
        header.write_text(original + '\n' + fragment)
}
do_unpack[vardeps] += "MACHINE_FEATURES"

SRC_URI:append:imx8mm-jaguar-inst = " \
    file://boot.cmd \
"
SRC_URI:append:imx8mm-jaguar-screen = " \
    file://boot.cmd \
"

SRC_URI:append:imx8mm-jaguar-handheld = " \
    file://boot.cmd \
"

SRC_URI:append:imx8mm-jaguar-phasora = " \
    file://boot.cmd \
"

SRC_URI:append:imx93-jaguar-eink = " \
    file://boot.cmd \
"

#SRC_URI:append:imx8ulp-lpddr4-evk = " \
#    file://boot.cmd \
#"
