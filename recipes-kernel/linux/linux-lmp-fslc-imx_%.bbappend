FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append:imx8mm-jaguar-sentai = " \
		file://enable_i2c-dev.cfg \
		file://enable_lp50xx.cfg \
        file://enable_usb_modem.cfg \
		file://enable_gpio_key.cfg \
		file://enable_stts22h.cfg \
		file://enable_lis2dh.cfg \
		file://enable_sht4x.cfg \
		file://disable_video.cfg \
		file://imx8mm-jaguar-sentai.dts \
		file://01-remove-wifi-warning.patch \
		file://01-fix-evkb-duplicate-label.patch \
        file://01-fix-enable-lp50xx.patch \
		file://02-disable-wifi-scan-msg.patch \
		file://03-enable-lis2dh12.cfg \
		file://04-enable-usb-gadgets.cfg \
		file://05-patch-led-defaults.patch \
        file://07-enable-tas2781-mainline.cfg \
        file://08-backport-tas2563-support-to-tas2781.patch \
                ${@bb.utils.contains('ENABLE_BOOT_PROFILING', '1', 'file://enable_boot_profiling.cfg', '', d)} \
"

# NOTE: This DTB file is created as a default for use with local development
#       when building lmp-base. It is NOT used by the lmp build or under CI
#       which uses the DTS in lmp-device-tree
do_configure:append:imx8mm-jaguar-sentai(){
 cp ${WORKDIR}/imx8mm-jaguar-sentai.dts ${S}/arch/arm64/boot/dts
 echo "dtb-y += imx8mm-jaguar-sentai.dtb" >> ${S}/arch/arm64/boot/dts/Makefile
}

# NOTE: Device tree is now provided by the BSP layer lmp-device-tree recipe
#       This ensures consistent DTS across all build types (lmp, lmp-base, CI)

SRC_URI:append:imx8mm-jaguar-inst = " \
		file://enable_i2c-dev.cfg \
                file://enable_usb_modem.cfg \
		file://enable_gpio_key.cfg \
		file://imx8mm-jaguar-inst.dts \
		file://02-disable-wifi-scan-msg.patch \
		file://04-enable-usb-gadgets.cfg \
                file://06-support-iwl_dev_tx_power_cmd_v8.patch \
                file://07-mvm_fix_a_crash_on_7265.patch \
		file://08-enable-micrel-phy.cfg \
"

# NOTE: This DTB file is created as a default for use with local development
#       when building lmp-base. It is NOT used by the lmp build or under CI
#       which uses the DTS in lmp-device-tree
do_configure:append:imx8mm-jaguar-inst(){
 cp ${WORKDIR}/imx8mm-jaguar-inst.dts ${S}/arch/arm64/boot/dts
 echo "dtb-y += imx8mm-jaguar-inst.dtb" >> ${S}/arch/arm64/boot/dts/Makefile
}

# NOTE: This DTB file is created as a default for use with local development
#       when building lmp-base. It is NOT used by the lmp build or under CI
#       which uses the DTS in lmp-device-tree
do_configure:append:imx8mm-jaguar-handheld(){
 cp ${WORKDIR}/imx8mm-jaguar-handheld.dts ${S}/arch/arm64/boot/dts
 echo "dtb-y += imx8mm-jaguar-handheld.dtb" >> ${S}/arch/arm64/boot/dts/Makefile
}

# NOTE: This DTB file is created as a default for use with local development
#       when building lmp-base. It is NOT used by the lmp build or under CI
#       which uses the DTS in lmp-device-tree
do_configure:append:imx8mm-jaguar-phasora(){
 cp ${WORKDIR}/imx8mm-jaguar-phasora.dts ${S}/arch/arm64/boot/dts
 echo "dtb-y += imx8mm-jaguar-phasora.dtb" >> ${S}/arch/arm64/boot/dts/Makefile
}

# TODO: Make binder module based on DISTRO
SRC_URI:append:imx8mm-jaguar-handheld = " \
		file://enable_i2c-dev.cfg \
		file://imx8mm-jaguar-handheld.dts \
                file://enable-binder.cfg \
		file://enable-iptables-ext.cfg \
		file://enable-erofs.cfg \
"

SRC_URI:append:imx8mm-jaguar-phasora = " \
		file://enable_i2c-dev.cfg \
		file://enable_ksz9563.cfg \
		file://enable_pca953x.cfg \
		file://enable_dwc3.cfg \
		file://enable_upd72020x_fw.cfg \
		file://imx8mm-jaguar-phasora.dts \
                file://0003-enable-st7701.cfg \
                file://0006-enable-edt-ft5x06.cfg \
		file://0007-load-firmware-to-synopsys-usb3.patch \
"

SRC_URI:append:imx93-jaguar-eink = " \
		file://imx93-jaguar-eink.dts \
		file://essential_drivers_only.cfg \
		file://enable_eink_display.cfg \
		file://enable_iw612_wifi.cfg \
		file://enable_iw612_bluetooth.cfg \
		file://enable_802154.cfg \
		file://enable_lte_modem.cfg \
		file://enable_spi.cfg \
		file://disable_all_sound.cfg \
		file://disable_imx56_video.cfg \
		file://disable_camera_hdmi.cfg \
		file://fix_soc_imx9.cfg \
		file://enable_power_management.cfg \
		file://enable_wifi_power_management.cfg \
		file://enable_ocotp_nvmem.cfg \
		file://enable_m33_support.cfg \
		${@bb.utils.contains('ENABLE_BOOT_PROFILING', '1', 'file://enable_boot_profiling.cfg', '', d)} \
"

# NOTE: This DTB file is created as a default for use with local development
#       when building lmp-base. It is NOT used by the lmp build or under CI
#       which uses the DTS in lmp-device-tree
do_configure:append:imx93-jaguar-eink(){
 cp ${WORKDIR}/imx93-jaguar-eink.dts ${S}/arch/arm64/boot/dts
 echo "dtb-y += imx93-jaguar-eink.dtb" >> ${S}/arch/arm64/boot/dts/Makefile
}

#do_configure:append:imx8mm-jaguar-phasora() {
#   for i in ../*.cfg; do
#      [ -f "$i" ] || break
#      bbdebug 2 "applying $i file contents to .config"
#      cat ../*.cfg >> ${B}/.config
#   done
#}
