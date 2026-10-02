SUMMARY = "TI TAS2555 ASoC amplifier driver"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://tas2555-core.c;beginline=1;endline=15;md5=da441b33b39736af307cf600ae06538e"

inherit module features_check

REQUIRED_MACHINE_FEATURES = "tas2555"

SRC_URI = "git://git.ti.com/tas2555sw-android/tas2555-android-driver.git;protocol=https;branch=master \
           file://Makefile \
           file://0001-tas2555-port-to-current-asoc-and-i2c-apis.patch \
           file://0002-tas2555-bound-firmware-parser-and-cleanup.patch \
           file://0003-tas2555-propagate-init-errors-and-limit-rates.patch \
           file://0004-tas2555-reject-runtime-firmware-reload.patch \
           file://0005-tas2555-fix-boost-off-selection.patch \
           file://0006-tas2555-add-explicit-dev-only-rom1-mode.patch \
          "
SRCREV = "0468cf54e49f57163e17998846b62dc941130929"

S = "${WORKDIR}/git"

do_configure() {
    install -m 0644 ${WORKDIR}/Makefile ${S}/Makefile
}
