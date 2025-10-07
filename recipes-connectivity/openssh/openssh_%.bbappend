FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://sshd_config_hardened \
            file://banner"

do_install:append() {
    # Install hardened SSH configuration
    install -m 600 ${WORKDIR}/sshd_config_hardened ${D}${sysconfdir}/ssh/sshd_config
    
    # Install security banner
    install -m 644 ${WORKDIR}/banner ${D}${sysconfdir}/ssh/banner
}
