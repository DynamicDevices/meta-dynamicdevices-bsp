SUMMARY = "MCUboot and Zephyr microcontroller support package group"
DESCRIPTION = "Package group for MCUboot secure bootloader and Zephyr RTOS \
firmware targeting microcontrollers used for power management and system control."

LICENSE = "MIT"

inherit packagegroup

# MCUboot core packages
RDEPENDS:${PN} = " \
    mcuboot \
    zephyr-mcxc444 \
"

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
