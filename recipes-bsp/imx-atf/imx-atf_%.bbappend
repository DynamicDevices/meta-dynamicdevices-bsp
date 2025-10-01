# ATF configuration for mfgtool builds
# For imx93 SoCs, ATF with OP-TEE support is REQUIRED for proper boot chain
# Only disable OP-TEE support for imx8mm SoCs where it's optional

# Disable OP-TEE support in ATF for imx8mm mfgtool builds
ATF_MACHINE_NAME:lmp-mfgtool:imx8mm-jaguar-sentai = "bl31-${ATF_PLATFORM}.bin"

# For imx93 mfgtool builds, ATF with OP-TEE support is REQUIRED - do NOT disable it
# No ATF_MACHINE_NAME override for imx93-jaguar-eink - use default with OP-TEE



