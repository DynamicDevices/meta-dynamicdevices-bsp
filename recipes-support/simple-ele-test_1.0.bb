SUMMARY = "Simple ELE Test for i.MX93"
DESCRIPTION = "Basic EdgeLock Enclave test utility"
LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://LICENSE;md5=8636bd68fc00cc6a3809b7b58b45f982"

FILESEXTRAPATHS:prepend := "${THISDIR}/nxp-ele-test-suite:"

SRC_URI = "file://simple-ele-test.c \
           file://LICENSE"

S = "${WORKDIR}"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} simple-ele-test.c -o simple-ele-test
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 simple-ele-test ${D}${bindir}/
}

FILES:${PN} = "${bindir}/simple-ele-test"
