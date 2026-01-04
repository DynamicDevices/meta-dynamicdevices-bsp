# Fix I2C interface detection bug in stm32flash 0.7
# The bug causes "Error probing interface serial_posix" when using I2C devices
# because stm32flash tries serial interfaces before I2C. This patch detects
# I2C devices by checking if the device path contains "i2c" and tries
# the I2C interface first, avoiding the serial_posix probe error.

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://0001-Fix-I2C-interface-detection-order.patch"

