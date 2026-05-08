# See firmware-taa5412/README.bin-provenance.md and firmware-taa5412_1.0.bb.disabled (template).

SUMMARY = "TI TAA5412-Q1 register-block firmware for snd_soc_pcm6240"
DESCRIPTION = "Installs the PCM6240-family firmware blob required by mainline pcm6240.c (ti,taa5412) for sound-taa5412 / taa5412-codec."
HOMEPAGE = "https://www.ti.com/product/TAA5412-Q1"
SECTION = "base"

# Vendor binary — ${THISDIR}/firmware-taa5412/taa5412-i2c-1-1dev.bin (TI redistribution policy applies).
LICENSE = "CLOSED"
LIC_FILES_CHKSUM = ""

FILESEXTRAPATHS:prepend := "${THISDIR}/firmware-taa5412:"

inherit allarch

PV = "1.0"
PR = "r0"

SRC_URI = "file://taa5412-i2c-1-1dev.bin"

S = "${WORKDIR}"

do_install() {
	install -d ${D}${nonarch_base_libdir}/firmware
	install -m 0644 ${WORKDIR}/taa5412-i2c-1-1dev.bin \
		${D}${nonarch_base_libdir}/firmware/taa5412-i2c-1-1dev.bin
	install -d ${D}${docdir}/${PN}
	install -m 0644 ${THISDIR}/firmware-taa5412/taa5412-1dev-reg.json ${D}${docdir}/${PN}/
	install -m 0644 ${THISDIR}/firmware-taa5412/TI-PCMJSN-ORIGIN.txt ${D}${docdir}/${PN}/
	install -m 0644 ${THISDIR}/firmware-taa5412/README.bin-provenance.md ${D}${docdir}/${PN}/
}

FILES:${PN} = " \
    ${nonarch_base_libdir}/firmware/taa5412-i2c-1-1dev.bin \
    ${docdir}/${PN}/taa5412-1dev-reg.json \
    ${docdir}/${PN}/TI-PCMJSN-ORIGIN.txt \
    ${docdir}/${PN}/README.bin-provenance.md \
"
