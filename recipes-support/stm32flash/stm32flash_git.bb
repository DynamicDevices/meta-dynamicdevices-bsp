SUMMARY = "Open source flash program for STM32 using the ST serial bootloader (Git version)"
DESCRIPTION = "Open source flash program for STM32 using the ST serial bootloader. \
This recipe uses the GitHub source which may include I2C fixes not in the 0.7 release."
HOMEPAGE = "https://github.com/ARMinARM/stm32flash"
BUGTRACKER = "https://github.com/ARMinARM/stm32flash/issues"
LICENSE = "GPL-2.0-or-later"
LIC_FILES_CHKSUM = "file://gpl-2.0.txt;md5=b234ee4d69f5fce4486a80fdaf4a4263"

# Use GitHub source for latest version with potential I2C fixes
# Using latest commit from master branch
SRC_URI = "git://github.com/ARMinARM/stm32flash.git;protocol=https;branch=master"
SRCREV = "2f2a55e81976643da2fad3ef2d806357286c90e7"

S = "${WORKDIR}/git"

PV = "0.7+git${SRCPV}"

# stm32flash uses a simple Makefile, no autotools needed
do_configure() {
    # No configure step needed - uses Makefile directly
    :
}

do_compile() {
    oe_runmake
}

do_install() {
    oe_runmake install DESTDIR=${D} PREFIX=${prefix}
}

# Package files
FILES:${PN} = "${bindir}/stm32flash"
