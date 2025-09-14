FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append:imx8mm-jaguar-sentai = " \
		file://i2c-dev-interface.cfg \
		file://imx8mm-jaguar-sentai/lp50xx-led-driver.cfg \
		file://usb-modem-support.cfg \
		file://gpio-keys.cfg \
		file://imx8mm-jaguar-sentai/stts22h-temperature-sensor.cfg \
		file://imx8mm-jaguar-sentai/lis2dh-accelerometer.cfg \
		file://imx8mm-jaguar-sentai/sht4x-humidity-sensor.cfg \
		file://imx8mm-jaguar-sentai/video-disable.cfg \
		file://imx8mm-jaguar-sentai/tas2562-audio-codec.cfg \
		file://lis2dh12-sensor.cfg \
		file://usb-gadgets.cfg \
		file://0001-wireless-remove-nl80211-regdom-warning.patch \
		file://0004-dts-imx8mm-evkb-fix-duplicate-label.patch \
		file://0005-dts-imx8mm-evkb-fix-lp50xx-led-driver.patch \
		file://0003-wireless-wilc1000-disable-scan-progress-message.patch \
		file://imx8mm-jaguar-sentai/0006-leds-lp50xx-set-default-configuration.patch \
		file://0002-asoc-tas2781-add-tas2563-codec-support.patch \
		${@bb.utils.contains('MACHINE_FEATURES', 'tas2781-mainline', 'file://tas2781-mainline-driver.cfg', '', d)} \
		${@bb.utils.contains('ENABLE_BOOT_PROFILING', '1', 'file://boot-profiling.cfg', '', d)} \
		file://imx8mm-jaguar-sentai.dts \
"

# NOTE: This DTB file is created as a default for use with local development
#       when building lmp-base. It is NOT used by the lmp build or under CI
#       which uses the DTS in lmp-device-tree
do_configure:append:imx8mm-jaguar-sentai(){
 if [ -f ${WORKDIR}/imx8mm-jaguar-sentai.dts ]; then
     cp ${WORKDIR}/imx8mm-jaguar-sentai.dts ${S}/arch/arm64/boot/dts
     echo "dtb-y += imx8mm-jaguar-sentai.dtb" >> ${S}/arch/arm64/boot/dts/Makefile
 else
     bbwarn "imx8mm-jaguar-sentai.dts not found in ${WORKDIR}, skipping DTS copy"
 fi
}

# NOTE: Device tree is now provided by the BSP layer lmp-device-tree recipe
#       This ensures consistent DTS across all build types (lmp, lmp-base, CI)

SRC_URI:append:imx8mm-jaguar-inst = " \
		file://i2c-dev-interface.cfg \
                file://usb-modem-support.cfg \
		file://gpio-keys.cfg \
		file://imx8mm-jaguar-inst.dts \
		file://0003-wireless-wilc1000-disable-scan-progress-message.patch \
		file://usb-gadgets.cfg \
                file://imx8mm-jaguar-inst/0001-wireless-iwlwifi-support-tx-power-cmd-v8.patch \
                file://imx8mm-jaguar-inst/0002-wireless-iwlwifi-mvm-fix-crash-on-7265.patch \
		file://imx8mm-jaguar-inst/micrel-phy-support.cfg \
"

# NOTE: This DTB file is created as a default for use with local development
#       when building lmp-base. It is NOT used by the lmp build or under CI
#       which uses the DTS in lmp-device-tree
do_configure:append:imx8mm-jaguar-inst(){
 if [ -f ${WORKDIR}/imx8mm-jaguar-inst.dts ]; then
     cp ${WORKDIR}/imx8mm-jaguar-inst.dts ${S}/arch/arm64/boot/dts
     echo "dtb-y += imx8mm-jaguar-inst.dtb" >> ${S}/arch/arm64/boot/dts/Makefile
 else
     bbwarn "imx8mm-jaguar-inst.dts not found in ${WORKDIR}, skipping DTS copy"
 fi
}

# NOTE: This DTB file is created as a default for use with local development
#       when building lmp-base. It is NOT used by the lmp build or under CI
#       which uses the DTS in lmp-device-tree
do_configure:append:imx8mm-jaguar-handheld(){
 if [ -f ${WORKDIR}/imx8mm-jaguar-handheld.dts ]; then
     cp ${WORKDIR}/imx8mm-jaguar-handheld.dts ${S}/arch/arm64/boot/dts
     echo "dtb-y += imx8mm-jaguar-handheld.dtb" >> ${S}/arch/arm64/boot/dts/Makefile
 else
     bbwarn "imx8mm-jaguar-handheld.dts not found in ${WORKDIR}, skipping DTS copy"
 fi
}

# NOTE: This DTB file is created as a default for use with local development
#       when building lmp-base. It is NOT used by the lmp build or under CI
#       which uses the DTS in lmp-device-tree
do_configure:append:imx8mm-jaguar-phasora(){
 if [ -f ${WORKDIR}/imx8mm-jaguar-phasora.dts ]; then
     cp ${WORKDIR}/imx8mm-jaguar-phasora.dts ${S}/arch/arm64/boot/dts
     echo "dtb-y += imx8mm-jaguar-phasora.dtb" >> ${S}/arch/arm64/boot/dts/Makefile
 else
     bbwarn "imx8mm-jaguar-phasora.dts not found in ${WORKDIR}, skipping DTS copy"
 fi
}

# TODO: Make binder module based on DISTRO
SRC_URI:append:imx8mm-jaguar-handheld = " \
		file://i2c-dev-interface.cfg \
		file://imx8mm-jaguar-handheld.dts \
                file://imx8mm-jaguar-handheld/android-binder.cfg \
		file://imx8mm-jaguar-handheld/iptables-extensions.cfg \
		file://imx8mm-jaguar-handheld/erofs-filesystem.cfg \
"

SRC_URI:append:imx8mm-jaguar-phasora = " \
		file://i2c-dev-interface.cfg \
		file://ksz9563-ethernet-switch.cfg \
		file://pca953x-gpio-expander.cfg \
		file://dwc3-usb.cfg \
		file://upd72020x-usb3-firmware.cfg \
		file://imx8mm-jaguar-phasora.dts \
                file://imx8mm-jaguar-phasora/st7701-display-driver.cfg \
                file://imx8mm-jaguar-phasora/edt-ft5x06-touchscreen.cfg \
		file://0006-usb-dwc3-synopsys-load-firmware-support.patch \
"

SRC_URI:append:imx93-jaguar-eink = " \
		file://imx93-jaguar-eink.dts \
		file://imx93-jaguar-eink/drivers-essential-only.cfg \
		file://imx93-jaguar-eink/eink-display-support.cfg \
		file://imx93-jaguar-eink/iw612-wifi.cfg \
		file://imx93-jaguar-eink/iw612-bluetooth.cfg \
		file://imx93-jaguar-eink/ieee802154-support.cfg \
		file://imx93-jaguar-eink/lte-modem-support.cfg \
		file://imx93-jaguar-eink/spi-support.cfg \
		file://imx93-jaguar-eink/sound-disable-all.cfg \
		file://imx93-jaguar-eink/imx56-video-disable.cfg \
		file://imx93-jaguar-eink/camera-hdmi-disable.cfg \
		file://imx93-jaguar-eink/imx9-soc-fixes.cfg \
		file://imx93-jaguar-eink/power-management.cfg \
		file://imx93-jaguar-eink/wifi-power-management.cfg \
		file://imx93-jaguar-eink/ocotp-nvmem-support.cfg \
		file://imx93-jaguar-eink/cortex-m33-support.cfg \
		${@bb.utils.contains('ENABLE_BOOT_PROFILING', '1', 'file://boot-profiling.cfg', '', d)} \
"

# NOTE: This DTB file is created as a default for use with local development
#       when building lmp-base. It is NOT used by the lmp build or under CI
#       which uses the DTS in lmp-device-tree
do_configure:append:imx93-jaguar-eink(){
 if [ -f ${WORKDIR}/imx93-jaguar-eink.dts ]; then
     cp ${WORKDIR}/imx93-jaguar-eink.dts ${S}/arch/arm64/boot/dts
     echo "dtb-y += imx93-jaguar-eink.dtb" >> ${S}/arch/arm64/boot/dts/Makefile
 else
     bbwarn "imx93-jaguar-eink.dts not found in ${WORKDIR}, skipping DTS copy"
 fi
}

#do_configure:append:imx8mm-jaguar-phasora() {
#   for i in ../*.cfg; do
#      [ -f "$i" ] || break
#      bbdebug 2 "applying $i file contents to .config"
#      cat ../*.cfg >> ${B}/.config
#   done
#}
