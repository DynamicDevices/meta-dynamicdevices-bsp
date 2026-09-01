# Common controls for machines with a physically mounted display panel.
#
# Each screen machine names the validated panel profile that its DTS selects
# and declares how the native panel scan is mounted in the product.
DISPLAY_PANEL_PROFILE ?= ""
DISPLAY_PANEL_ROTATION ?= "0"
DISPLAY_FBCON_ROTATE ?= "0"

# Foundries OSTree writes this into each deployment's /boot/loader/uEnv.txt,
# so the console orientation survives OTA updates.
OSTREE_KERNEL_ARGS:append = " fbcon=rotate:${DISPLAY_FBCON_ROTATE}"
