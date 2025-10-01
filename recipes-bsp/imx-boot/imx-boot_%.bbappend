# OP-TEE configuration for mfgtool builds
# For imx93 SoCs, OP-TEE is REQUIRED for proper boot chain operation
# Only disable OP-TEE for imx8mm SoCs where it's optional

# Disable OP-TEE for imx8mm mfgtool builds (OP-TEE is optional)
TEE_BINARY:lmp-mfgtool:imx8mm-jaguar-sentai = ""
DEPLOY_OPTEE:lmp-mfgtool:imx8mm-jaguar-sentai = "false"

# For imx93 mfgtool builds, OP-TEE is REQUIRED - do NOT disable it
# No TEE_BINARY or DEPLOY_OPTEE overrides for imx93-jaguar-eink

# Use correct boot targets for different SoC families
# imx93 uses flash_singleboot, imx8mm uses flash_evk
IMXBOOT_TARGETS:lmp-mfgtool:imx93-jaguar-eink = "flash_singleboot"
