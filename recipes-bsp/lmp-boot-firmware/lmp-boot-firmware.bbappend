FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# Staged MCU / companion images for LmP `lmp-boot-firmware` (factory / provisioning artefacts).
# This path is distinct from FEATURE_mcuboot / ZEPHYR_PMU_PN packages on the rootfs.
# imx93-jaguar-eink / imx8mm-jaguar-dt510 each use a machine-specific `*/zephyr.bin` (see do_unpack:append).
# imx8mm-jaguar-* (except DT510) still use top-level `zephyr.bin`.

# Only add Zephyr firmware for Dynamic Devices machines that need it
LMP_BOOT_FIRMWARE_FILES:append:imx8mm-jaguar-sentai = " zephyr.bin"
LMP_BOOT_FIRMWARE_FILES:append:imx8mm-jaguar-dt510 = " zephyr.bin"
LMP_BOOT_FIRMWARE_FILES:append:imx8mm-jaguar-inst = " zephyr.bin"
LMP_BOOT_FIRMWARE_FILES:append:imx8mm-jaguar-handheld = " zephyr.bin"
LMP_BOOT_FIRMWARE_FILES:append:imx8mm-jaguar-phasora = " zephyr.bin"
LMP_BOOT_FIRMWARE_FILES:append:imx93-jaguar-eink = " zephyr.bin"

# Only add zephyr.bin source for Dynamic Devices machines that need it
SRC_URI:append:imx8mm-jaguar-sentai = " file://zephyr.bin"
SRC_URI:append:imx8mm-jaguar-dt510 = " file://imx8mm-jaguar-dt510/zephyr.bin"
SRC_URI:append:imx8mm-jaguar-inst = " file://zephyr.bin"
SRC_URI:append:imx8mm-jaguar-handheld = " file://zephyr.bin"
SRC_URI:append:imx8mm-jaguar-phasora = " file://zephyr.bin"
SRC_URI:append:imx93-jaguar-eink = " file://imx93-jaguar-eink/zephyr.bin"

# lmp-boot-firmware do_install expects ${WORKDIR}/zephyr.bin (flat).
# Do not use do_unpack:append:<machine>() — hyphens in MACHINE break BitBake's shell-function
# parse and the body is mistaken for Python. Branch on ${MACHINE} inside do_unpack:append() instead.
do_unpack:append() {
    if [ "${MACHINE}" = "imx8mm-jaguar-dt510" ] && [ -f "${WORKDIR}/imx8mm-jaguar-dt510/zephyr.bin" ]; then
        install -m0644 "${WORKDIR}/imx8mm-jaguar-dt510/zephyr.bin" "${WORKDIR}/zephyr.bin"
    fi
    if [ "${MACHINE}" = "imx93-jaguar-eink" ] && [ -f "${WORKDIR}/imx93-jaguar-eink/zephyr.bin" ]; then
        install -m0644 "${WORKDIR}/imx93-jaguar-eink/zephyr.bin" "${WORKDIR}/zephyr.bin"
    fi
}
