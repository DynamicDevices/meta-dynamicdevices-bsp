FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# Only add Intel WiFi firmware for Dynamic Devices machines that need it
SRC_URI:append:imx8mm-jaguar-sentai = " file://iwlwifi-ty-a0-gf-a0-59.ucode"
SRC_URI:append:imx8mm-jaguar-inst = " file://iwlwifi-ty-a0-gf-a0-59.ucode"
SRC_URI:append:imx8mm-jaguar-handheld = " file://iwlwifi-ty-a0-gf-a0-59.ucode"
SRC_URI:append:imx8mm-jaguar-phasora = " file://iwlwifi-ty-a0-gf-a0-59.ucode"
SRC_URI:append:imx93-jaguar-eink = " file://iwlwifi-ty-a0-gf-a0-59.ucode"

do_install:append:imx8mm-jaguar-sentai() {
    install -d ${D}/${nonarch_base_libdir}/firmware
    install -m 0644 ${WORKDIR}/iwlwifi-ty-a0-gf-a0-59.ucode ${D}/${nonarch_base_libdir}/firmware/iwlwifi-ty-a0-gf-a0-59.ucode
}

do_install:append:imx8mm-jaguar-inst() {
    install -d ${D}/${nonarch_base_libdir}/firmware
    install -m 0644 ${WORKDIR}/iwlwifi-ty-a0-gf-a0-59.ucode ${D}/${nonarch_base_libdir}/firmware/iwlwifi-ty-a0-gf-a0-59.ucode
}

do_install:append:imx8mm-jaguar-handheld() {
    install -d ${D}/${nonarch_base_libdir}/firmware
    install -m 0644 ${WORKDIR}/iwlwifi-ty-a0-gf-a0-59.ucode ${D}/${nonarch_base_libdir}/firmware/iwlwifi-ty-a0-gf-a0-59.ucode
}

do_install:append:imx8mm-jaguar-phasora() {
    install -d ${D}/${nonarch_base_libdir}/firmware
    install -m 0644 ${WORKDIR}/iwlwifi-ty-a0-gf-a0-59.ucode ${D}/${nonarch_base_libdir}/firmware/iwlwifi-ty-a0-gf-a0-59.ucode
}

do_install:append:imx93-jaguar-eink() {
    install -d ${D}/${nonarch_base_libdir}/firmware
    install -m 0644 ${WORKDIR}/iwlwifi-ty-a0-gf-a0-59.ucode ${D}/${nonarch_base_libdir}/firmware/iwlwifi-ty-a0-gf-a0-59.ucode
}

FILES:${PN}-iwlwifi-ax210 += " \
       ${nonarch_base_libdir}/firmware/iwlwifi-ty-a0-gf-a0-59.ucode \
"

PACKAGES += " ${PN}-iwlwifi-ax210"

RPROVIDES:${PN} += "${PN}-iwlwifi-ax210"

#INSANE_SKIP += " ldflags"
#INSANE_SKIP:${PN} += " ldflags"
