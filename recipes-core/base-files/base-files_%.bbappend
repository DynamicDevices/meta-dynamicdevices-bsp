FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://motd"

do_install:append() {
    # Install custom MOTD with proper alignment
    install -m 644 ${WORKDIR}/motd ${D}${sysconfdir}/motd
}
