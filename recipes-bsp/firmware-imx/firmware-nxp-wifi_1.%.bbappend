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
    
    # Configure firmware type based on build configuration
    # Use secure firmware (.se) for production, regular (.bin) for development
    if [ "${NXP_WIFI_SECURE_FIRMWARE}" = "1" ]; then
        # More robust sed command that handles whitespace and line endings
        sed -i '/SDIW612 = {/,/^}/ s|fw_name=nxp/sduart_nw61x_v1\.bin|fw_name=nxp/sduart_nw61x_v1.bin.se|g' ${D}${nonarch_base_libdir}/firmware/nxp/wifi_mod_para.conf
        bbwarn "Using secure NXP WiFi firmware (.se files) - ensure secure boot is configured"
    else
        # Ensure we use standard firmware for development builds
        sed -i '/SDIW612 = {/,/^}/ s|fw_name=nxp/sduart_nw61x_v1\.bin\.se|fw_name=nxp/sduart_nw61x_v1.bin|g' ${D}${nonarch_base_libdir}/firmware/nxp/wifi_mod_para.conf
        bbwarn "Using standard NXP WiFi firmware (.bin files) - suitable for development"
    fi
}

FILES:${PN} += "${sysconfdir}/NetworkManager/conf.d/99-ignore-uap.conf"
