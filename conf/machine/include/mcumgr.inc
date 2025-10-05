# MCUmgr Machine Feature Configuration
# Enables MCUmgr command-line tool for managing Zephyr RTOS devices with MCUboot bootloader
# Specifically designed for boards with dedicated microcontrollers for power management

# Machine feature definition
MACHINE_FEATURES_BACKFILL_CONSIDERED:append = " mcumgr"

# Add MCUmgr package when the machine feature is present
MACHINE_EXTRA_RRECOMMENDS:append = " \
    ${@bb.utils.contains('MACHINE_FEATURES', 'mcumgr', 'mcumgr', '', d)} \
"

# Add useful serial communication tools for MCUmgr
MACHINE_EXTRA_RRECOMMENDS:append = " \
    ${@bb.utils.contains('MACHINE_FEATURES', 'mcumgr', 'screen minicom', '', d)} \
"

# Add development tools when debug features are enabled
MACHINE_EXTRA_RRECOMMENDS:append = " \
    ${@bb.utils.contains_any('MACHINE_FEATURES IMAGE_FEATURES', 'mcumgr debug-tweaks', 'python3-serial python3-pyserial strace', '', d)} \
"

# Configure serial device permissions for mcumgr access
# Add user to dialout group for serial device access
EXTRA_USERS_PARAMS:append = " \
    ${@bb.utils.contains('MACHINE_FEATURES', 'mcumgr', 'groupadd dialout; usermod -a -G dialout root;', '', d)} \
"
