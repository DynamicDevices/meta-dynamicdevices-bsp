MACHINE_EXTRA_RDEPENDS:append = "${@bb.utils.contains('MACHINE_FEATURES', 'tas2555', ' kernel-module-snd-soc-tas2555', '', d)}"

# The imported driver fails probe unless this speaker/device configuration is
# available.  Keep module and DT development possible, but fail image creation
# rather than producing an audio-labelled rootfs with a guaranteed dead card.
TAS2555_FIRMWARE_FILE = "${nonarch_base_libdir}/firmware/tas2555_uCDSP.bin"

jaguar_screen_tas2555_validate_rootfs() {
    if ${@bb.utils.contains('MACHINE_FEATURES', 'tas2555-rom1-dev', 'true', 'false', d)}; then
        if [ "${DEV_MODE}" != "1" ]; then
            bbfatal "tas2555-rom1-dev is an unprotected development mode and requires DEV_MODE=1"
        fi
        bbnote "tas2555-rom1-dev selected: allowing the explicit unprotected DEV ROM1 path without speaker firmware"
        return
    fi

    if [ ! -s "${IMAGE_ROOTFS}${TAS2555_FIRMWARE_FILE}" ]; then
        bbfatal "tas2555 is enabled but ${TAS2555_FIRMWARE_FILE} is missing or empty; install the board's speaker-specific PurePath device configuration"
    fi
}

ROOTFS_POSTPROCESS_COMMAND:append = "${@bb.utils.contains('MACHINE_FEATURES', 'tas2555', ' jaguar_screen_tas2555_validate_rootfs;', '', d)}"
