SUMMARY = "TI TAS2781 Smart Amplifier Driver with TAS2563 Hardware Support"
DESCRIPTION = "Advanced Linux driver for TI TAS2781/TAS2563 smart amplifiers with DSP support, \
firmware loading, and echo reference functionality for audio applications."
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://tasdevice-codec.c;beginline=1;endline=14;md5=bf3ad78054a3e702be98b345c246c294"

inherit module


SRC_URI = "git://github.com/DynamicDevices/tas2781-linux-driver.git;branch=master;protocol=https \
           file://INT8866RCA2-single.bin \
           file://TAS2XXX3870.bin \
           file://01-fix-kernel-6.6-compatibility.patch \
          "
SRCREV = "${AUTOREV}"

S = "${WORKDIR}/git/src"

do_configure() {
}

do_install:append() {
  install -d ${D}${nonarch_base_libdir}/firmware
  # Install official TAS2563 regbin firmware (modified for single device) from Linux firmware repository
  install -m 644 ${WORKDIR}/INT8866RCA2-single.bin ${D}${nonarch_base_libdir}/firmware/tas2563-1amp-reg.bin
  # Install official TAS2563 DSP firmware from Linux firmware repository  
  install -m 644 ${WORKDIR}/TAS2XXX3870.bin ${D}${nonarch_base_libdir}/firmware/tas2563-1amp-dsp.bin
}

FILES:${PN} += "/lib/modules*" 
FILES:${PN} += "${nonarch_base_libdir}/firmware/tas2563-1amp-reg.bin" 
FILES:${PN} += "${nonarch_base_libdir}/firmware/tas2563-1amp-dsp.bin" 

KERNEL_MODULE_AUTOLOAD:append = "snd-soc-tas2781"
