# FRDM-IMX95: signed FIT boot with the product-owned HDMI splash.
setenv bootlimit 3
setenv devtype mmc
setenv devnum 0
setenv bootpart 1
setenv rootpart 2

if test -z "${frdm_dtb}"; then setenv frdm_dtb imx95-15x15-frdm.dtb; fi
setenv fdtfile ${frdm_dtb}
setenv fdt_file ${frdm_dtb}
setenv fdt_file_final ${frdm_dtb}
setenv fit_addr ${initrd_addr}

# NXP's current IT6263 U-Boot driver supports 720p. Failure is non-fatal so a
# missing or late HDMI monitor cannot delay recovery or unattended headless boot.
if load mmc ${devnum}:${bootpart} ${splashimage} active-edge-splash-1280x720.bmp; then
	if bmp display ${splashimage}; then
		echo "Active-Edge U-Boot splash displayed"
	else
		echo "Active-Edge U-Boot splash skipped: display unavailable"
	fi
fi

setenv bootloader 0x0
setenv bootloader2 0x300
setenv bootloader_s ${bootloader}
setenv bootloader2_s ${bootloader2}

setenv bootloader_image "imx-boot"
setenv bootloader_s_image ${bootloader_image}
setenv bootloader2_image "u-boot.itb"
setenv bootloader2_s_image ${bootloader2_image}

setenv update_image_boot0 'echo "${fio_msg} writing ${image_path} ..."; run set_blkcnt && mmc dev ${devnum} 1 && mmc write ${loadaddr} ${start_blk} ${blkcnt}'
setenv update_image_user 'echo "${fio_msg} writing ${image_path} ..."; run set_blkcnt && mmc dev ${devnum} 0 && mmc write ${loadaddr} ${start_blk} ${blkcnt}'

setenv backup_primary_image 'echo "${fio_msg} backing up primary boot image set ..."; mmc dev ${devnum} 1 && mmc read ${loadaddr} 0x0 0x2000 && mmc dev ${devnum} 2 && mmc write ${loadaddr} 0x0 0x2000'
setenv restore_primary_image 'echo "${fio_msg} restoring primary boot image set ..."; mmc dev ${devnum} 2 && mmc read ${loadaddr} 0x0 0x2000 && mmc dev ${devnum} 1 && mmc write ${loadaddr} 0x0 0x2000'

setenv update_primary_image1 'if test "${ostree_deploy_usr}" = "1"; then setenv image_path "${bootdir}/${bootloader_s_image}"; else setenv image_path "${ostree_root}/usr/lib/firmware/${bootloader_s_image}"; fi; setenv start_blk "${bootloader_s}"; run load_image; run update_image_boot0'
setenv update_primary_image2 'if test "${ostree_deploy_usr}" = "1"; then setenv image_path "${bootdir}/${bootloader2_s_image}"; else setenv image_path "${ostree_root}/usr/lib/firmware/${bootloader2_s_image}"; fi; setenv start_blk "${bootloader2_s}"; run load_image; run update_image_user'

setenv update_primary_image 'run update_primary_image1; run update_primary_image2'
setenv do_reboot "reset"

@@INCLUDE_COMMON_IMX@@
@@INCLUDE_COMMON_ALTERNATIVE@@
