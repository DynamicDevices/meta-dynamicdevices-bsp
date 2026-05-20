SUMMARY = "TI TAC5x1x family ASoC codec (out-of-tree)"
DESCRIPTION = "Out-of-tree module from TI lpaa-android-drivers/tac5x1x-linux-driver. \
Enabled with MACHINE_FEATURES tac5x1x-ti-audio (mutually exclusive with tac5x1x-audio Lore in-kernel stack)."
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${S}/tac5x1x-i2c.c;beginline=1;endline=10;md5=470d432f2ae41d873b421da159632ecd"

inherit module

FILESEXTRAPATHS:prepend := "${THISDIR}/kernel-module-tac5x1x-ti:"

SRC_URI = "git://git.ti.com/git/lpaa-android-drivers/tac5x1x-linux-driver.git;branch=tac5x1x_driver_k5.15;protocol=https \
           file://Makefile \
           file://0001-linux-6.6-i2c-driver-api.patch \
           file://0002-add-ti-tac5301-compatible.patch \
          "
SRCREV = "8348635b6f54f7111092bf0247f63a80bc31d8ec"

S = "${WORKDIR}/git/src"

do_configure:prepend() {
    install -m 0644 ${WORKDIR}/Makefile ${S}/Makefile
}

KERNEL_MODULE_AUTOLOAD:append = " snd-soc-tac5x1x"

python __anonymous () {
    if not bb.utils.contains('MACHINE_FEATURES', 'tac5x1x-ti-audio', True, False, d):
        raise bb.parse.SkipRecipe('tac5x1x-ti-audio not in MACHINE_FEATURES')
}
