SUMMARY = "DT510 codec boot ALSA mixer init scripts"
DESCRIPTION = "Systemd oneshot units for DT510 ALSA: ensure /etc/asound.conf, TAS6424 tannoy, TAS2563 driver speaker, and TAA5412 driver mic mixer defaults on imx8mm-jaguar-dt510"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

# Reuse init scripts from alsa-state (asound.conf stays in alsa-state.bbappend).
FILESEXTRAPATHS:prepend := "${THISDIR}/../alsa-state/alsa-state/imx8mm-jaguar-dt510:"

SRC_URI = " \
    file://tas6424-init.sh \
    file://tas6424-init.service \
    file://tas2563-init.sh \
    file://tas2563-init.service \
    file://taa5412-init.sh \
    file://taa5412-init.service \
    file://dt510-ensure-asound-conf.sh \
    file://dt510-ensure-asound-conf.service \
"

S = "${WORKDIR}"

RDEPENDS:${PN} = "alsa-utils alsa-state bash"

inherit systemd

SYSTEMD_SERVICE:${PN} = "dt510-ensure-asound-conf.service tas6424-init.service tas2563-init.service taa5412-init.service"

COMPATIBLE_MACHINE = "imx8mm-jaguar-dt510"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/dt510-ensure-asound-conf.sh ${D}${bindir}/dt510-ensure-asound-conf
    install -m 0755 ${WORKDIR}/tas6424-init.sh ${D}${bindir}/tas6424-init
    install -m 0755 ${WORKDIR}/tas2563-init.sh ${D}${bindir}/tas2563-init
    install -m 0755 ${WORKDIR}/taa5412-init.sh ${D}${bindir}/taa5412-init

    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${WORKDIR}/dt510-ensure-asound-conf.service ${D}${systemd_unitdir}/system/
    install -m 0644 ${WORKDIR}/tas6424-init.service ${D}${systemd_unitdir}/system/
    install -m 0644 ${WORKDIR}/tas2563-init.service ${D}${systemd_unitdir}/system/
    install -m 0644 ${WORKDIR}/taa5412-init.service ${D}${systemd_unitdir}/system/
}

FILES:${PN} = " \
    ${bindir}/dt510-ensure-asound-conf \
    ${bindir}/tas6424-init \
    ${bindir}/tas2563-init \
    ${bindir}/taa5412-init \
    ${systemd_unitdir}/system/dt510-ensure-asound-conf.service \
    ${systemd_unitdir}/system/tas6424-init.service \
    ${systemd_unitdir}/system/tas2563-init.service \
    ${systemd_unitdir}/system/taa5412-init.service \
"

pkg_postinst:${PN}() {
    if [ -z "$D" ]; then
        # Remove stale /etc drop-ins superseded by dt510-audio-init package units.
        rm -f /etc/systemd/system/tas6424-init.service
        rm -f /etc/systemd/system/tas2563-init.service
        rm -f /etc/systemd/system/taa5412-init.service
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}
