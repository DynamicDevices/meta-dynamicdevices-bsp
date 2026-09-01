echo "Using imx8mm-jaguar-screen.dtb"

# Default boot type and device
setenv bootlimit 3
setenv devtype mmc
setenv devnum 2
setenv bootpart 1
setenv rootpart 2

# Boot image files
setenv fdt_file_final imx8mm-jaguar-screen.dtb
setenv fit_addr ${initrd_addr}

# Display the full-screen, pre-rotated Active-Edge artwork when the U-Boot
# HX8279 panel driver is available. Failure is deliberately non-fatal so
# recovery and unattended boot remain possible on headless hardware.
if load mmc ${devnum}:${bootpart} ${loadaddr} active-edge-splash-1200x1920.bmp; then
	if bmp display ${loadaddr}; then
		echo "Active-Edge U-Boot splash displayed"
	else
		echo "Active-Edge U-Boot splash skipped: display unavailable"
	fi
fi

# Boot firmware updates

# Offsets are in blocks (512KB each)
setenv bootloader 0x42
setenv bootloader2 0x300
setenv bootloader_s 0x1042
setenv bootloader2_s 0x1300

setenv bootloader_image "imx-boot"
setenv bootloader_s_image ${bootloader_image}
setenv bootloader2_image "u-boot.itb"
setenv bootloader2_s_image ${bootloader2_image}
setenv uboot_hwpart 1

@@INCLUDE_COMMON_IMX@@
@@INCLUDE_COMMON@@
