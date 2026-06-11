SUMMARY = "MCUboot and Zephyr microcontroller support package group"
DESCRIPTION = "Package group for MCUboot secure bootloader and Zephyr RTOS \
firmware targeting microcontrollers used for power management and system control."

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit packagegroup

RDEPENDS:${PN} = "mcuboot"

RDEPENDS:${PN}:append = "${@(' ' + d.getVar('ZEPHYR_PMU_PN')) if d.getVar('ZEPHYR_PMU_PN') else ''}"

# Programming and development tools
RDEPENDS:${PN} += " \
    python3-cryptography \
    python3-click \
    python3-cbor2 \
    python3-intelhex \
    python3-pyelftools \
    python3-pyyaml \
"

# Optional debugging tools for development builds
RDEPENDS:${PN} += " \
    ${@bb.utils.contains('IMAGE_FEATURES', 'debug-tweaks', 'gdb', '', d)} \
"

# Machine-specific dependencies
RDEPENDS:${PN}:append:imx93-jaguar-eink = " \
    kernel-module-spi-imx \
    kernel-module-i2c-imx \
"
