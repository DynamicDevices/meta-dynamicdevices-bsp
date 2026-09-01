FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# API 59 remains the legacy firmware for existing Dynamic Devices machines.
SRC_URI:append:imx8mm-jaguar-sentai = " file://iwlwifi-ty-a0-gf-a0-59.ucode"
SRC_URI:append:imx8mm-jaguar-inst = " file://iwlwifi-ty-a0-gf-a0-59.ucode"
SRC_URI:append:imx8mm-jaguar-handheld = " file://iwlwifi-ty-a0-gf-a0-59.ucode"
SRC_URI:append:imx8mm-jaguar-phasora = " file://iwlwifi-ty-a0-gf-a0-59.ucode"
SRC_URI:append:imx93-jaguar-eink = " file://iwlwifi-ty-a0-gf-a0-59.ucode"

# Jaguar SCREEN: API 83 and matching PNVM pinned from the official
# linux-firmware 20240709 release. API 59 is retained as a fallback.
# iwlwifi-ty-a0-gf-a0-83.ucode:
#   c90da88a6dc8b159e14e378f66d52f52eb553dacdb90f053da612fc68668b7a6
# iwlwifi-ty-a0-gf-a0.pnvm:
#   a94382882a54a07afc8f4305011b6515d95043669e31d2d0aaa975b13698e8b2
SRC_URI:append:imx8mm-jaguar-screen = " \
    file://iwlwifi-ty-a0-gf-a0-59.ucode \
    file://iwlwifi-ty-a0-gf-a0-83.ucode \
    file://iwlwifi-ty-a0-gf-a0.pnvm \
"

do_install_legacy_ax210_firmware() {
    install -d ${D}${nonarch_base_libdir}/firmware
    install -m 0644 ${WORKDIR}/iwlwifi-ty-a0-gf-a0-59.ucode \
        ${D}${nonarch_base_libdir}/firmware/iwlwifi-ty-a0-gf-a0-59.ucode
}

do_install:append:imx8mm-jaguar-sentai() {
    do_install_legacy_ax210_firmware
}

do_install:append:imx8mm-jaguar-inst() {
    do_install_legacy_ax210_firmware
}

do_install:append:imx8mm-jaguar-screen() {
    do_install_legacy_ax210_firmware
    install -m 0644 ${WORKDIR}/iwlwifi-ty-a0-gf-a0-83.ucode \
        ${D}${nonarch_base_libdir}/firmware/iwlwifi-ty-a0-gf-a0-83.ucode
    install -m 0644 ${WORKDIR}/iwlwifi-ty-a0-gf-a0.pnvm \
        ${D}${nonarch_base_libdir}/firmware/iwlwifi-ty-a0-gf-a0.pnvm
}

do_install:append:imx8mm-jaguar-handheld() {
    do_install_legacy_ax210_firmware
}

do_install:append:imx8mm-jaguar-phasora() {
    do_install_legacy_ax210_firmware
}

do_install:append:imx93-jaguar-eink() {
    do_install_legacy_ax210_firmware
}

# Prepend so this specific package claims the firmware before ${PN}'s broad
# firmware file patterns are evaluated during package splitting.
PACKAGES =+ "${PN}-iwlwifi-ax210"

FILES:${PN}-iwlwifi-ax210 += " \
    ${nonarch_base_libdir}/firmware/iwlwifi-ty-a0-gf-a0-59.ucode \
    ${nonarch_base_libdir}/firmware/iwlwifi-ty-a0-gf-a0-83.ucode \
    ${nonarch_base_libdir}/firmware/iwlwifi-ty-a0-gf-a0.pnvm \
"
