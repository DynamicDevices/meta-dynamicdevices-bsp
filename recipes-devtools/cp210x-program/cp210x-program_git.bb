SUMMARY = "Read/write Silicon Labs CP210x USB UART EEPROM (userspace, PyUSB)"
DESCRIPTION = "Python tool to read or program the on-chip EEPROM of Silabs CP210x bridges. \
Useful on boards such as DT510 (CP2108) for inspecting USB descriptor and GPIO/RS-485-related \
configuration. CP2108: UART [0]/[1] RS-232, [2]/[3] RS-485 (+ GPIO.10/14 DE per datasheet when programmed). \
Upstream does not certify CP2108; prefer read/compare on hardware before production writes."
HOMEPAGE = "https://github.com/VCTLabs/cp210x-program"
SECTION = "devel"
LICENSE = "LGPL-2.1-only"
LIC_FILES_CHKSUM = "file://LICENSE;md5=a70cf540abf41acb644ac3b621b2fad1"

SRCBRANCH = "master"
SRCREV = "927ed264fe4a3aeb360cd0e7862bfb19b8c2e6bb"
PV = "0.4.1+git${SRCPV}"

SRC_URI = "git://github.com/VCTLabs/cp210x-program;protocol=https;branch=${SRCBRANCH}"

S = "${WORKDIR}/git"

inherit setuptools3

RDEPENDS:${PN} += "python3-core python3-ctypes python3-pyusb"

# Upstream script uses "#!/usr/bin/env python"; images typically have python3 only.
do_install:append() {
	if [ -f "${D}${bindir}/cp210x-program.py" ]; then
		sed -i '1s@^#!.*@#!/usr/bin/env python3@' "${D}${bindir}/cp210x-program.py"
		ln -sf cp210x-program.py "${D}${bindir}/cp210x-program"
	fi
}
