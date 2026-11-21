FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append:imx8mm-jaguar-sentai = " \
        file://imx8mm-jaguar-sentai.dts \
        ${@bb.utils.contains('MACHINE_FEATURES', 'xm125-radar', 'file://imx8mm-jaguar-sentai-xm125-radar.dtso', '', d)} \
"

SRC_URI:append:imx8mm-jaguar-dt510 = " \
        file://imx8mm-jaguar-dt510.dts \
        file://imx8mm-sw_pad_ctl.h \
        file://imx8mm-sw_pad_ctl-fields.h \
"

COMPATIBLE_MACHINE:imx8mm-jaguar-sentai = ".*"
COMPATIBLE_MACHINE:imx8mm-jaguar-dt510 = ".*"

# Only the headed DT510 kernel advertises the boot-display handover ABI.
DTC_PPFLAGS:append:imx8mm-jaguar-dt510 = " ${@bb.utils.contains('DISTRO_FEATURES', 'display-boot-splash', '-DAESL_CONTINUOUS_DISPLAY', '', d)}"

# Check the compiled artifact, not merely the source-level preprocessor guard.
# Manufacturing/headless images must not opt in to the handover ABI.
python do_compile:append:imx8mm-jaguar-dt510() {
    import os
    import subprocess

    dtb = os.path.join(d.getVar("B"), "imx8mm-jaguar-dt510.dtb")
    properties = subprocess.check_output(
        ["fdtget", "-p", dtb, "/"], text=True).splitlines()
    expected = "display-boot-splash" in (d.getVar("DISTRO_FEATURES") or "").split()
    actual = "aesl,continuous-display-v1" in properties
    if actual != expected:
        bb.fatal("DT510 compiled DTB handover opt-in does not match display-boot-splash")
}

SRC_URI:append:imx8mm-jaguar-inst = " \
        file://imx8mm-jaguar-inst.dts \
"
SRC_URI:append:imx8mm-jaguar-screen = " \
        file://imx8mm-jaguar-screen.dts \
        file://imx8mm-sw_pad_ctl.h \
        file://imx8mm-sw_pad_ctl-fields.h \
"

COMPATIBLE_MACHINE:imx8mm-jaguar-inst = ".*"
COMPATIBLE_MACHINE:imx8mm-jaguar-screen = ".*"

SRC_URI:append:imx8mm-jaguar-phasora = " \
        file://imx8mm-jaguar-phasora.dts \
"

COMPATIBLE_MACHINE:imx8mm-jaguar-phasora = ".*"

SRC_URI:append:imx8mm-jaguar-handheld = " \
        file://imx8mm-jaguar-handheld.dts \
"

COMPATIBLE_MACHINE:imx8mm-jaguar-handheld = ".*"

SRC_URI:append:imx8ulp-lpddr4-evk = " \
        file://imx8ulp-evk.dts \
"

COMPATIBLE_MACHINE:imx8ulp-lpddr4-evk = ".*"

SRC_URI:append:imx93-jaguar-eink = " \
        file://imx93-jaguar-eink.dts \
"

COMPATIBLE_MACHINE:imx93-jaguar-eink = ".*"

SRC_URI:append:imx93-11x11-lpddr4x-evk = " \
        file://imx93-11x11-evk.dts \
"

COMPATIBLE_MACHINE:imx93-11x11-lpddr4x-evk = ".*"
