# Disable OP-TEE entirely for mfgtool builds
# OP-TEE is only needed for production runtime, not for board programming

# For mfgtool distro, completely remove OP-TEE from the boot image
TEE_BINARY:lmp-mfgtool = ""
DEPLOY_OPTEE:lmp-mfgtool = "false"

# Use correct boot target for imx93 (flash_singleboot, not flash_evk_no_hdmi)
IMXBOOT_TARGETS:lmp-mfgtool = "flash_singleboot"
