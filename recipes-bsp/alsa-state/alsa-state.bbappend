FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# Install machine-specific ALSA configuration files
SRC_URI:append:imx8mm-jaguar-sentai = " \
    file://asound.conf \
    file://tas2563-init.sh \
"

do_install:append:imx8mm-jaguar-sentai() {
    # Install the main ALSA configuration
    install -d ${D}${sysconfdir}
    install -m 0644 ${WORKDIR}/asound.conf ${D}${sysconfdir}/asound.conf
    
    # Install TAS2563 initialization script
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/tas2563-init.sh ${D}${bindir}/tas2563-init
    
    # Remove ALSA state directory to prevent state file creation
    rm -rf ${D}${localstatedir}/lib/alsa
}

FILES:${PN}:append:imx8mm-jaguar-sentai = " \
    ${sysconfdir}/asound.conf \
    ${bindir}/tas2563-init \
"
