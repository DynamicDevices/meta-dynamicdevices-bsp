FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

#do_install:append() {
#    sed -i 's/ps_mode=1/ps_mode=2/g' ${D}${nonarch_base_libdir}/firmware/nxp/wifi_mod_para.conf
#    sed -i 's/auto_ds=1/auto_ds=2/g' ${D}${nonarch_base_libdir}/firmware/nxp/wifi_mod_para.conf
#}

#SRC_URI:append = "\
#    file://wifi-disable-power-saving.conf \
#"

#do_install:append() {
#    sed -i 's/ps_mode=1/ps_mode=0/g' ${D}${nonarch_base_libdir}/firmware/nxp/wifi_mod_para.conf
#    install -d ${D}${sysconfdir}/modprobe.d
#    install -D -m 0644 ${WORKDIR}/wifi-disable-power-saving.conf ${D}${sysconfdir}/modprobe.d/wifi-disable-power-saving.conf
#}

#FILES:${PN} += "${sysconfdir}/modprobe.d/wifi-disable-power-saving.conf"

# Only apply NetworkManager configuration for Dynamic Devices machines
SRC_URI:append:imx8mm-jaguar-sentai = "\
    file://99-ignore-uap.conf \
    file://wifi_mod_para.conf \
"
SRC_URI:append:imx8mm-jaguar-inst = "\
    file://99-ignore-uap.conf \
"
SRC_URI:append:imx8mm-jaguar-handheld = "\
    file://99-ignore-uap.conf \
"
SRC_URI:append:imx8mm-jaguar-phasora = "\
    file://99-ignore-uap.conf \
"
SRC_URI:append:imx93-jaguar-eink = "\
    file://99-ignore-uap.conf \
    file://wifi_mod_para.conf \
"

do_install:append:imx8mm-jaguar-sentai() {
    install -d ${D}${sysconfdir}/NetworkManager/conf.d
    install -D -m 0644 ${WORKDIR}/99-ignore-uap.conf ${D}${sysconfdir}/NetworkManager/conf.d/99-ignore-uap.conf
    
    # Install custom WiFi module parameters for sentai (same as eink)
    install -D -m 0644 ${WORKDIR}/wifi_mod_para.conf ${D}${nonarch_base_libdir}/firmware/nxp/wifi_mod_para.conf
    
    # Configure firmware type based on build configuration
    # Default to secure firmware (.se) for production cloud builds
    # Use insecure firmware (.bin) only when explicitly requested for development
    if [ "${NXP_WIFI_INSECURE_FIRMWARE}" = "1" ]; then
        # Use standard firmware for development builds (when explicitly requested)
        sed -i '/SDIW612 = {/,/^}/ s|fw_name=nxp/sduart_nw61x_v1\.bin\.se|fw_name=nxp/sduart_nw61x_v1.bin|g' ${D}${nonarch_base_libdir}/firmware/nxp/wifi_mod_para.conf
        bbwarn "Using insecure NXP WiFi firmware (.bin files) - development mode"
    else
        # Default: Use secure firmware for production cloud builds
        sed -i '/SDIW612 = {/,/^}/ s|fw_name=nxp/sduart_nw61x_v1\.bin|fw_name=nxp/sduart_nw61x_v1.bin.se|g' ${D}${nonarch_base_libdir}/firmware/nxp/wifi_mod_para.conf
        bbwarn "Using secure NXP WiFi firmware (.se files) - production mode"
    fi
}

do_install:append:imx8mm-jaguar-inst() {
    install -d ${D}${sysconfdir}/NetworkManager/conf.d
    install -D -m 0644 ${WORKDIR}/99-ignore-uap.conf ${D}${sysconfdir}/NetworkManager/conf.d/99-ignore-uap.conf
}

do_install:append:imx8mm-jaguar-handheld() {
    install -d ${D}${sysconfdir}/NetworkManager/conf.d
    install -D -m 0644 ${WORKDIR}/99-ignore-uap.conf ${D}${sysconfdir}/NetworkManager/conf.d/99-ignore-uap.conf
}

do_install:append:imx8mm-jaguar-phasora() {
    install -d ${D}${sysconfdir}/NetworkManager/conf.d
    install -D -m 0644 ${WORKDIR}/99-ignore-uap.conf ${D}${sysconfdir}/NetworkManager/conf.d/99-ignore-uap.conf
}

do_install:append:imx93-jaguar-eink() {
    install -d ${D}${sysconfdir}/NetworkManager/conf.d
    install -D -m 0644 ${WORKDIR}/99-ignore-uap.conf ${D}${sysconfdir}/NetworkManager/conf.d/99-ignore-uap.conf
    
    # Install custom WiFi module parameters for IW612
    install -D -m 0644 ${WORKDIR}/wifi_mod_para.conf ${D}${nonarch_base_libdir}/firmware/nxp/wifi_mod_para.conf
    
    # CRITICAL: Install BOTH secure and non-secure firmware files
    # Upstream recipe only installs .bin.se (secure) files by default
    # We need BOTH so the same image works on secured and unsecured devices
    #
    # Install non-secure (.bin) firmware files from source:
    if [ -f "${S}/nxp/FwImage_IW612_SD/sduart_nw61x_v1.bin" ]; then
        install -m 0644 ${S}/nxp/FwImage_IW612_SD/sduart_nw61x_v1.bin ${D}${nonarch_base_libdir}/firmware/nxp/
        install -m 0644 ${S}/nxp/FwImage_IW612_SD/sd_w61x_v1.bin ${D}${nonarch_base_libdir}/firmware/nxp/
        install -m 0644 ${S}/nxp/FwImage_IW612_SD/uartspi_n61x_v1.bin ${D}${nonarch_base_libdir}/firmware/nxp/
        bbwarn "imx93-jaguar-eink: Installed non-secure WiFi firmware files (.bin)"
    else
        bbwarn "imx93-jaguar-eink: WARNING - Non-secure firmware files not found in source!"
    fi
    
    # The NXP WiFi driver automatically detects device secure boot state and selects:
    # - Unsecured device (DEV_MODE=1) → loads .bin firmware
    # - Secured device (production) → loads .bin.se firmware
    #
    # Now both firmware types are installed:
    # - /lib/firmware/nxp/sduart_nw61x_v1.bin (standard, installed above)
    # - /lib/firmware/nxp/sduart_nw61x_v1.bin.se (secure, from upstream recipe)
    #
    # Default to standard firmware in module config - driver will upgrade to .se if device is secured
    sed -i '/SDIW612 = {/,/^}/ s|fw_name=nxp/sduart_nw61x_v1\.bin\.se|fw_name=nxp/sduart_nw61x_v1.bin|g' ${D}${nonarch_base_libdir}/firmware/nxp/wifi_mod_para.conf
    bbwarn "imx93-jaguar-eink: WiFi firmware configured for automatic selection - works on both secured and unsecured devices"
}

FILES:${PN} += "${sysconfdir}/NetworkManager/conf.d/99-ignore-uap.conf"

# Add non-secure firmware files to the nxpiw612-sdio package
FILES:${PN}-nxpiw612-sdio += " \
    ${nonarch_base_libdir}/firmware/nxp/sduart_nw61x_v1.bin \
    ${nonarch_base_libdir}/firmware/nxp/sd_w61x_v1.bin \
    ${nonarch_base_libdir}/firmware/nxp/uartspi_n61x_v1.bin \
"
