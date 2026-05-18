# FRDM-IMX95 (imx95-frdm-evk) — NXP imx95-15x15-frdm.dtb
setenv bootlimit 3
setenv devtype mmc
setenv devnum 0
setenv bootpart 1
setenv rootpart 2

setenv fdt_file imx95-15x15-frdm.dtb
setenv fdt_file_final imx95-15x15-frdm.dtb
setenv fit_addr ${initrd_addr}

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
