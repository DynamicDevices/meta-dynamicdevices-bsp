# TAS2781 Mainline Driver Configuration
# This configuration enables the mainline TAS2781 driver with TAS2563 support
# replacing the buggy out-of-tree TI driver

# Machine feature definition
MACHINE_FEATURES_BACKFILL_CONSIDERED:append = " tas2781-mainline"

# TAS2781 driver is built into kernel with TAS2563 support patch
# Remove the old out-of-tree drivers to avoid conflicts and add firmware
MACHINE_EXTRA_RRECOMMENDS:remove = " \
    ${@bb.utils.contains('MACHINE_FEATURES', 'tas2781-mainline', 'kernel-module-tas2781 kernel-module-tas2563', '', d)} \
"

# Add TAS2563 firmware for mainline TAS2781 driver
MACHINE_EXTRA_RRECOMMENDS:append = " \
    ${@bb.utils.contains('MACHINE_FEATURES', 'tas2781-mainline', 'firmware-tas2563', '', d)} \
"

# Ensure proper module loading order
KERNEL_MODULE_PROBECONF:append = " \
    ${@bb.utils.contains('MACHINE_FEATURES', 'tas2781-mainline', 'snd-soc-tas2781-i2c', '', d)} \
"

# Configure TAS2781 module parameters for optimal TAS2563 operation
module_conf_snd-soc-tas2781-i2c = "options snd-soc-tas2781-i2c reset_gpio_active_high=0"
