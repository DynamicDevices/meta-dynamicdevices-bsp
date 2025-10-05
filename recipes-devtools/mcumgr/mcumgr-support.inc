#
# MCUmgr support for Zephyr RTOS device management
#
# This include file adds mcumgr command-line tool to the image
# for managing Zephyr RTOS devices with MCUboot bootloader support.
#
# Usage: Add to your image recipe:
#   require recipes-devtools/mcumgr/mcumgr-support.inc
#

# Add mcumgr package to the image
IMAGE_INSTALL += "mcumgr"

# Add useful serial communication tools
IMAGE_INSTALL += "screen minicom"

# Development and debugging tools that work well with mcumgr
IMAGE_INSTALL += "bash coreutils findutils grep sed"

# Optional: Add Python for advanced scripting (if not already included)
# IMAGE_INSTALL += "python3-core python3-serial"
