# LMP Feature: MCUboot Integration
# Provides MCUboot bootloader and Zephyr firmware for microcontrollers
# Used on boards with dedicated power management microcontrollers

SUMMARY = "MCUboot bootloader and Zephyr firmware support"
DESCRIPTION = "This feature adds MCUboot secure bootloader and Zephyr RTOS \
firmware support for microcontrollers used in power management and system control. \
Includes programming tools and development utilities."

# MCUboot and Zephyr packages
CORE_IMAGE_BASE_INSTALL += " \
    mcuboot \
    zephyr-mcxc444 \
"

# Development and programming tools
CORE_IMAGE_BASE_INSTALL += " \
    python3-cryptography \
    python3-click \
    python3-cbor2 \
    python3-intelhex \
    python3-pyelftools \
    python3-pyyaml \
"

# Optional debugging tools (only in development builds)
CORE_IMAGE_BASE_INSTALL += " \
    ${@bb.utils.contains('IMAGE_FEATURES', 'debug-tweaks', 'gdb openocd', '', d)} \
"

# Feature documentation
IMAGE_FEATURES_REPLACES_mcuboot = ""
IMAGE_FEATURES_CONFLICTS_mcuboot = ""

# Add mcuboot feature to available image features
FEATURE_PACKAGES_mcuboot = "packagegroup-mcuboot"
