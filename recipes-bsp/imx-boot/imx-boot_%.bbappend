# Disable OP-TEE entirely for mfgtool builds
# OP-TEE is only needed for production runtime, not for board programming

# For mfgtool distro, completely remove OP-TEE from the boot image
TEE_BINARY:lmp-mfgtool = ""
DEPLOY_OPTEE:lmp-mfgtool = "false"

# Use correct boot targets for different SoC families
# imx93 uses flash_singleboot, imx8mm uses flash_evk
IMXBOOT_TARGETS:lmp-mfgtool:imx93-jaguar-eink = "flash_singleboot"
