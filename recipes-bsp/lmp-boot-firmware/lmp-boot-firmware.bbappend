FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# Only add Zephyr firmware for Dynamic Devices machines that need it
LMP_BOOT_FIRMWARE_FILES:append:imx8mm-jaguar-sentai = " zephyr.bin"
LMP_BOOT_FIRMWARE_FILES:append:imx8mm-jaguar-inst = " zephyr.bin"
LMP_BOOT_FIRMWARE_FILES:append:imx8mm-jaguar-handheld = " zephyr.bin"
LMP_BOOT_FIRMWARE_FILES:append:imx8mm-jaguar-phasora = " zephyr.bin"
LMP_BOOT_FIRMWARE_FILES:append:imx93-jaguar-eink = " zephyr.bin"

# Only add zephyr.bin source for Dynamic Devices machines that need it
SRC_URI:append:imx8mm-jaguar-sentai = " file://zephyr.bin"
SRC_URI:append:imx8mm-jaguar-inst = " file://zephyr.bin"
SRC_URI:append:imx8mm-jaguar-handheld = " file://zephyr.bin"
SRC_URI:append:imx8mm-jaguar-phasora = " file://zephyr.bin"
SRC_URI:append:imx93-jaguar-eink = " file://zephyr.bin"
