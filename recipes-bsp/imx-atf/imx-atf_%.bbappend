# Disable OP-TEE support in ATF for mfgtool builds
# OP-TEE is only needed for production runtime, not for board programming

# For mfgtool distro, use ATF without OP-TEE support
ATF_MACHINE_NAME:lmp-mfgtool = "bl31-${ATF_PLATFORM}.bin"



