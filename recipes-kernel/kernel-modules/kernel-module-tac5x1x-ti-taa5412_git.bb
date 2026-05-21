SUMMARY = "TI TAC5x1x ASoC codec — TAA5412-only OOT (DT510 driver mic @ 0x51)"
DESCRIPTION = "Out-of-tree module from TI lpaa-android-drivers/tac5x1x-linux-driver, \
built as snd-soc-tac5x1x-taa5412 with OF match limited to ti,taa5412. \
Enabled with MACHINE_FEATURES taa5412-tac5x1x-ti (mutually exclusive with taa5412 pcm6240). \
Cabin loop TAC5301 @ 0x50 stays on Lore in-kernel tac5x1x-audio."
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${S}/tac5x1x-i2c.c;beginline=1;endline=10;md5=f43a32783f11042d7777a153f3bc192e"

inherit module

FILESEXTRAPATHS:prepend := "${THISDIR}/kernel-module-tac5x1x-ti-taa5412:${THISDIR}/kernel-module-tac5x1x-ti:"

SRC_URI = "git://git.ti.com/git/lpaa-android-drivers/tac5x1x-linux-driver.git;branch=tac5x1x_driver_k5.15;protocol=https \
           file://Makefile \
           file://0001-linux-6.6-i2c-driver-api.patch \
           file://0002-taa5412-only-of-match.patch \
           file://0003-lore-dapm-routes-taa5412.patch \
           file://0004-adc-cm-tolerance-ac-coupled.patch \
          "
SRCREV = "8348635b6f54f7111092bf0247f63a80bc31d8ec"

S = "${WORKDIR}/git/src"

do_configure:prepend() {
    install -m 0644 ${WORKDIR}/Makefile ${S}/Makefile
}

KERNEL_MODULE_AUTOLOAD:append = " snd-soc-tac5x1x-taa5412"

python __anonymous () {
    if not bb.utils.contains('MACHINE_FEATURES', 'taa5412-tac5x1x-ti', True, False, d):
        raise bb.parse.SkipRecipe('taa5412-tac5x1x-ti not in MACHINE_FEATURES')
}
