FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://sshd_config_hardened"

do_install:append() {
    # Install hardened SSH configuration
    install -m 600 ${WORKDIR}/sshd_config_hardened ${D}${sysconfdir}/ssh/sshd_config
    
    # Note: SSH banner is now provided by base-files recipe as symlink
    # to shared Dynamic Devices banner at /usr/share/dynamic-devices/banner
}
