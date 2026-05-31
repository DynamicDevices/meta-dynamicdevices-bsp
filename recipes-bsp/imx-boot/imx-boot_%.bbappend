# OP-TEE configuration for mfgtool builds
# For imx93 SoCs, OP-TEE is REQUIRED for proper boot chain operation
# Only disable OP-TEE for imx8mm SoCs where it's optional

# Disable OP-TEE for imx8mm mfgtool builds (OP-TEE is optional)
TEE_BINARY:lmp-mfgtool:imx8mm-jaguar-sentai = ""
DEPLOY_OPTEE:lmp-mfgtool:imx8mm-jaguar-sentai = "false"
TEE_BINARY:lmp-mfgtool:imx8mm-jaguar-dt510 = ""
DEPLOY_OPTEE:lmp-mfgtool:imx8mm-jaguar-dt510 = "false"

# For imx93 mfgtool builds, OP-TEE is REQUIRED - do NOT disable it
# No TEE_BINARY or DEPLOY_OPTEE overrides for imx93-jaguar-eink

# Use correct boot targets for different SoC families
# imx93 uses flash_singleboot, imx8mm uses flash_evk
IMXBOOT_TARGETS:lmp-mfgtool:imx93-jaguar-eink = "flash_singleboot"

# imx95 (mx95): use A55 boot target for mfgtool (not imx93 flash_singleboot)
IMXBOOT_TARGETS:lmp-mfgtool:imx95-frdm-evk = "flash_a55"

# imx95-frdm-evk uses flash_a55 (A55-only); meta-imx imx-boot_1.0.bbappend always
# copies imx-m7-demos into m7_image.bin for mx95, but FRDM has no mcore-demos yet.
IMX_M4_DEMOS:imx95-frdm-evk = ""
M4_DEFAULT_IMAGE_MX95:imx95-frdm-evk = "m7_image_placeholder.bin"

do_compile:prepend:imx95-frdm-evk() {
    # Satisfy meta-imx mx95 prepend cp; flash_a55 does not consume m7_image.bin.
    install -d ${DEPLOY_DIR_IMAGE}/mcore-demos
    install -m 0644 /dev/null ${DEPLOY_DIR_IMAGE}/mcore-demos/${M4_DEFAULT_IMAGE_MX95}
}
