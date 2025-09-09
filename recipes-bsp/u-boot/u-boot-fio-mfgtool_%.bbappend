FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

inherit lmp-signing-override

# Disable SE050 for mfgtools builds to prevent initialization errors during programming
# SE050 is only needed for production runtime, not for UUU programming operations
# Apply to all Dynamic Devices i.MX93 machines that use SE050
SRC_URI:append:imx93-jaguar-eink = " file://disable-se050.cfg"

# Override OP-TEE binary for mfgtool builds to use the mfgtool-specific OP-TEE
# The regular OP-TEE binary has SE050 enabled, but mfgtool needs SE050 disabled
do_deploy:prepend() {
    # Use the mfgtool-specific OP-TEE binary from the work directory
    # Convert machine name from hyphens to underscores for work directory path
    MACHINE_UNDERSCORE=$(echo "${MACHINE}" | tr '-' '_')
    MFGTOOL_OPTEE_PATH="${TMPDIR}/work/${MACHINE_UNDERSCORE}-lmp-linux/optee-os-fio-mfgtool/4.4.0/sysroot-destdir/usr/lib/firmware/tee-pager_v2.bin"
    if [ -f "${MFGTOOL_OPTEE_PATH}" ]; then
        # Replace the regular OP-TEE binary with the mfgtool one in the deploy directory
        mkdir -p ${DEPLOY_DIR_IMAGE}/optee/
        cp "${MFGTOOL_OPTEE_PATH}" "${DEPLOY_DIR_IMAGE}/optee/tee-pager_v2.bin"
        echo "Replaced OP-TEE binary with mfgtool version: ${MFGTOOL_OPTEE_PATH}"
    else
        echo "Warning: mfgtool OP-TEE binary not found at ${MFGTOOL_OPTEE_PATH}"
    fi
}
