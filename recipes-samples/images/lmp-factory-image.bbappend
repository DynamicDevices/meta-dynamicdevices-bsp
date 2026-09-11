# BSP-specific additions to lmp-factory-image
# Hardware-specific packages for Dynamic Devices boards

# XM125 Radar Module Support (Sentai board)
# Include XM125 firmware and tools when xm125-radar machine feature is enabled
CORE_IMAGE_BASE_INSTALL:append:imx8mm-jaguar-sentai = " \
    ${@bb.utils.contains('MACHINE_FEATURES', 'xm125-radar', 'xm125-firmware', '', d)} \
"

# Standard product boot-display contract. Machines opt in and select a native
# bootloader derivative while the common Linux client owns branded composition
# and compositor takeover.
DD_BOOT_SPLASH_ENABLE ?= "0"
DD_BOOT_SPLASH_ENABLE:imx8mm-jaguar-screen = "1"
DD_BOOT_SPLASH_ENABLE:imx95-frdm-evk = "1"

DD_BOOT_SPLASH_BMP ?= ""
DD_BOOT_SPLASH_BMP:imx8mm-jaguar-screen = "active-edge-splash-1200x1920.bmp"
DD_BOOT_SPLASH_BMP:imx95-frdm-evk = "active-edge-splash-1280x720.bmp"

# Keep printk/getty on the serial console so they cannot overwrite the branded
# framebuffer during the U-Boot -> Linux transition.
OSTREE_KERNEL_ARGS:remove:imx95-frdm-evk = "console=tty1"
OSTREE_KERNEL_ARGS:append:imx95-frdm-evk = " quiet loglevel=3 vt.global_cursor_default=0"

CORE_IMAGE_BASE_INSTALL:append = " ${@'screen-splash' if d.getVar('DD_BOOT_SPLASH_ENABLE') == '1' else ''}"

# psplash remains installed by the base image for other machines, but its
# Foundries artwork is disabled for Screen by recipes-core/psplash.

# Put the U-Boot-native BMP beside the FIT/DTB in the boot filesystem.
IMAGE_BOOT_FILES:append = " ${@d.getVar('DD_BOOT_SPLASH_BMP') if d.getVar('DD_BOOT_SPLASH_ENABLE') == '1' else ''}"
do_image_wic[depends] += "screen-uboot-splash:do_deploy"
