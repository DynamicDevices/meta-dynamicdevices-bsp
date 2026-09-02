# Common controls for machines with a physically mounted display panel.
#
# Each screen machine names the validated panel profile that its DTS selects
# and declares how the native panel scan is mounted in the product.
DISPLAY_PANEL_PROFILE ?= ""
DISPLAY_PANEL_ROTATION ?= "0"
DISPLAY_FBCON_ROTATE ?= "0"
DISPLAY_PANEL_NATIVE_WIDTH ?= ""
DISPLAY_PANEL_NATIVE_HEIGHT ?= ""
DISPLAY_PANEL_PIXELCLOCK_KHZ ?= ""
DISPLAY_PANEL_DSI_LANES ?= ""
DISPLAY_PANEL_DSI_FORMAT ?= ""
DISPLAY_PANEL_LINUX_COMPATIBLE ?= ""
DISPLAY_PANEL_UBOOT_DRIVER ?= ""
DISPLAY_PANEL_UBOOT_CONFIG ?= ""

# Foundries OSTree writes this into each deployment's /boot/loader/uEnv.txt,
# so the console orientation survives OTA updates.
OSTREE_KERNEL_ARGS:append = " fbcon=rotate:${DISPLAY_FBCON_ROTATE}"
