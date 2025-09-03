FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# Install machine-specific ALSA configuration files
SRC_URI:append:imx8mm-jaguar-sentai = " \
    file://asound.conf \
    file://asound-tas2563-mics.conf \
"

do_install:append:imx8mm-jaguar-sentai() {
    # Install the main ALSA configuration
    install -d ${D}${sysconfdir}
    install -m 0644 ${WORKDIR}/asound.conf ${D}${sysconfdir}/asound.conf
    
    # Install alternative TAS2563 microphone configuration
    install -d ${D}${datadir}/alsa
    install -m 0644 ${WORKDIR}/asound-tas2563-mics.conf ${D}${datadir}/alsa/asound-tas2563-mics.conf
}

do_install:append() {
    # Remove ALSA state directory to prevent state file creation
    rm -rf ${D}${localstatedir}/lib/alsa
}

FILES:${PN}:append:imx8mm-jaguar-sentai = " \
    ${sysconfdir}/asound.conf \
    ${datadir}/alsa/asound-tas2563-mics.conf \
"
