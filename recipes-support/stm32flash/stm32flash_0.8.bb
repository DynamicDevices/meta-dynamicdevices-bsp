SUMMARY = "Open source flash program for STM32 using the ST serial bootloader"
HOMEPAGE = "https://github.com/DynamicDevices/stm32flash"
BUGTRACKER = "https://github.com/DynamicDevices/stm32flash/issues"
LICENSE = "GPL-2.0-or-later"
LIC_FILES_CHKSUM = "file://gpl-2.0.txt;md5=b234ee4d69f5fce4486a80fdaf4a4263"

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI = "git://github.com/DynamicDevices/stm32flash.git;protocol=https;branch=master"

SRCREV = "441411a5dcf931f129d145cb2489f2477f15687f"

S = "${WORKDIR}/git"

# Fix I2C interface detection bug in stm32flash
# The bug causes "Error probing interface serial_posix" when using I2C devices
# because stm32flash tries serial interfaces before I2C. This patch detects
# I2C devices by checking if the device path contains "i2c" and tries
# the I2C interface first, avoiding the serial_posix probe error.
SRC_URI += "file://0001-Fix-I2C-interface-detection-order.patch"

do_install() {
	oe_runmake install DESTDIR=${D} PREFIX=${prefix}
}
