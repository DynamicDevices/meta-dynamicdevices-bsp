# DT510 early AESL splash. Remove hdmi-boot-splash to retain baseline U-Boot.
# This is hardware-specific, not a DISTRO_FEATURES switch.
# The machine's single feature-list assignment enables this feature by default.
# Keep the manufacturing/recovery bootloader on its original EVK control DT.
MACHINE_FEATURES:remove:lmp-mfgtool:imx8mm-jaguar-dt510 = " hdmi-boot-splash"
UBOOT_DTB_NAME:imx8mm-jaguar-dt510 = "${@bb.utils.contains('MACHINE_FEATURES', 'hdmi-boot-splash', 'imx8mm-jaguar-dt510-uboot.dtb', '${KERNEL_DEVICETREE_BASENAME}.dtb', d)}"
IMAGE_BOOT_FILES:append:imx8mm-jaguar-dt510 = " ${@bb.utils.contains('MACHINE_FEATURES', 'hdmi-boot-splash', 'active-edge-splash-1280x720.bmp', '', d)}"
