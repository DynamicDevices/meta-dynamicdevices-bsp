SUMMARY = "GPT partition table fix utility"
DESCRIPTION = "Fixes GPT partition table errors during boot using parted"
LICENSE = "CC-BY-NC-4.0"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/CC-BY-NC-4.0;md5=4612c2b904fda122f27a1687c73e1b1a"

SRC_URI = " \
    file://gpt-fix.sh \
    file://gpt-fix.service \
"

S = "${WORKDIR}"

inherit systemd

SYSTEMD_SERVICE:${PN} = "gpt-fix.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

# Only install on machines with eMMC storage that might have GPT issues
COMPATIBLE_MACHINE = "imx93-jaguar-eink"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/gpt-fix.sh ${D}${bindir}/gpt-fix.sh
    
    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${WORKDIR}/gpt-fix.service ${D}${systemd_unitdir}/system/
}

FILES:${PN} += " \
    ${bindir}/gpt-fix.sh \
    ${systemd_unitdir}/system/gpt-fix.service \
"

RDEPENDS:${PN} += "parted systemd"
