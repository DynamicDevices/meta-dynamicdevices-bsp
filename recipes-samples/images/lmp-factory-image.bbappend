# BSP-specific additions to lmp-factory-image
# Hardware-specific packages for Dynamic Devices boards

# XM125 Radar Module Support (Sentai board)
# Include XM125 firmware and tools when xm125-radar machine feature is enabled
CORE_IMAGE_BASE_INSTALL:append:imx8mm-jaguar-sentai = " \
    ${@bb.utils.contains('MACHINE_FEATURES', 'xm125-radar', 'xm125-firmware', '', d)} \
"

# Show the canonical Active-Edge lockup as soon as the Screen DRM output binds.
CORE_IMAGE_BASE_INSTALL:append:imx8mm-jaguar-screen = " screen-splash"

# psplash remains installed by the base image for other machines, but its
# Foundries artwork is disabled for Screen by recipes-core/psplash.

# Put the U-Boot-native BMP beside the FIT/DTB in the boot filesystem.
IMAGE_BOOT_FILES:append:imx8mm-jaguar-screen = " active-edge-splash-1200x1920.bmp"
do_image_wic[depends] += "screen-uboot-splash:do_deploy"
