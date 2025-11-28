FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://sshd_config_hardened"
SRC_URI:append:imx8mm-jaguar-sentai = " file://banner"

do_install:append() {
    # Install hardened SSH configuration
    install -m 600 ${WORKDIR}/sshd_config_hardened ${D}${sysconfdir}/ssh/sshd_config
}

do_install:append:imx8mm-jaguar-sentai() {
    # Install Sentai-specific banner for SSH and MOTD
    install -m 644 ${WORKDIR}/banner ${D}${sysconfdir}/ssh/banner
}
