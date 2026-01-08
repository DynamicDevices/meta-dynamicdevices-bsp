# Use Dynamic Devices fork of stm32flash with OBL_LAUNCH support for STM32L43xxx/44xxx
# This version includes fixes for clearing empty flash flag without power-on reset

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI = "git://github.com/DynamicDevices/stm32flash.git;protocol=https;branch=master"

SRCREV = "11a3c5eda7fe0e88c00f9c4ffbea02774de325c1"

S = "${WORKDIR}/git"

# Fix I2C interface detection bug in stm32flash
# The bug causes "Error probing interface serial_posix" when using I2C devices
# because stm32flash tries serial interfaces before I2C. This patch detects
# I2C devices by checking if the device path contains "i2c" and tries
# the I2C interface first, avoiding the serial_posix probe error.
SRC_URI += "file://0001-Fix-I2C-interface-detection-order.patch"
