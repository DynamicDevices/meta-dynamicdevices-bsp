SUMMARY = "TI TAS2563/TAS2781 Smart Amplifier Driver"
DESCRIPTION = "Texas Instruments TAS2563/TAS2781 smart amplifier driver with DSP support"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://src/tasdevice.h;beginline=1;endline=14;md5=8177f97513213526df2cf6184d2e1d38"

inherit module

SRC_URI = "git://git.ti.com/tas2781-linux-drivers/tas2781-linux-driver.git;branch=master;protocol=https"
SRCREV = "124282c12d471a53a2302881788c008fc2d3c364"

S = "${WORKDIR}/git"

# The driver source is in the src/ subdirectory
EXTRA_OEMAKE += "KDIR=${STAGING_KERNEL_DIR}"

do_configure() {
    # No configuration needed
}

do_compile() {
    unset CFLAGS CPPFLAGS CXXFLAGS LDFLAGS
    oe_runmake -C ${STAGING_KERNEL_DIR} M=${S}/src modules
}

do_install() {
    unset CFLAGS CPPFLAGS CXXFLAGS LDFLAGS
    oe_runmake -C ${STAGING_KERNEL_DIR} M=${S}/src INSTALL_MOD_PATH=${D} modules_install
}

FILES:${PN} += "${base_libdir}/modules/${KERNEL_VERSION}/extra/snd-soc-tasdevice.ko"

RPROVIDES:${PN} += "kernel-module-snd-soc-tasdevice"

# Auto-load the module
KERNEL_MODULE_AUTOLOAD += "snd-soc-tasdevice"

# Dependencies
RDEPENDS:${PN} += "kernel-module-snd-soc-core"
RDEPENDS:${PN} += "kernel-module-regmap-i2c"

# Available for machines with TAS2563 hardware (using TAS2781 driver)
COMPATIBLE_MACHINE = "(.*)"
COMPATIBLE_MACHINE:class-target = "${@bb.utils.contains('MACHINE_FEATURES', 'tas2563', '(.*)', 'null', d)}"
